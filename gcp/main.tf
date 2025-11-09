# Output available zones in the selected region
data "google_compute_zones" "available" {
  region = var.gcp_region
}

# GCP does not use filters to search for images, but you can either use the image name or the image family.
# The image family is a way to group images, and when you use it, GCP will always return the latest non-deprecated image in that family.
# In this case, we are using the "debian-11" family from the "debian-cloud" project, which will always return the latest Debian 11 image available.
# This is equivalent to using filters in AWS to always get the latest version of an AMI.
data "google_compute_image" "debian_11" {
  family  = "debian-11" # in the AWS example we are deploying a Bitnami Tomcat image, but for simplicity we are using a common Debian image here
  project = "debian-cloud"
}

locals {
  # Define common tags to be used across modules for better organization and management
  tags = {
    # VPC tag applied to routes and VM instances to allow egress internet access
    vpc_egress = "egress-inet"
    # Firewall tag applied to the web server firewall rules
    web_firewall = "web-firewall-compliant"
  }
} 

# Import the custom network module to create the VPC, subnets, firewall rules, NAT, and load balancer
module "network" {
  source = "./modules/network"
  gcp_project_id = var.gcp_project_id
  gcp_region     = var.gcp_region
  gcp_zone       = data.google_compute_zones.available.names[0]  # Use the first available zone in the selected region
  vpc            = {
    network_name = "test-vpc"
    # GLOBAL: routes are applied to all subnets in the VPC, regardless of the region
    # REGIONAL: routes are applied only to subnets in the same region as the route
    routing_mode = "GLOBAL"
    # Define subnets for the VPC.
    # We start defining a single subnet in the VPC, we can add more later if needed.
    subnets = [{
      name = "subnet-01"
      # CIDR block for the subnet
      ip   = "10.10.10.0/24"
      # Subnet region
      region = var.gcp_region
    }]
    # Define routes for the VPC.
    # Use custom routes to better control egress traffic from the VPC and assign routes to specific VM using network tags.
    # This pattern allows to increase security and compliance. By default, GCP creates an automatic route to allow all VM in the VPC to access internet,
    # this is not compliant with GDPR/HIPAA regulations, since you cannot control which VM can access internet and which cannot.
    routes = [{
      name                   = "egress-internet"
      description            = "route through IGW to access internet"
      destination_range      = "0.0.0.0/0"
      tags                   = [local.tags.vpc_egress]
      # the next hop to this route will be the default internet gateway
      next_hop_internet      = "true"
      priority               = 1000
    }]
  }
  firewall       = {
    name                        = "web-firewall"
    target_tag                  = local.tags.web_firewall
    # Configure CIDR blocks allowed to access the web server
    # Since we use a LB to manage ingress traffic,
    # we need to allow a specific set of GCP IPs, because the LB is managed by GCP and uses these IP ranges to forward traffic to the backend VMs.
    allowed_ingress_cidr_blocks = ["35.191.0.0/16", "130.211.0.0/22"] # Google Health Check ranges
    # Configure CIDR blocks allowed for egress traffic; for now we allow all outbound traffic, but this should be restricted in a production environment
    allowed_egress_cidr_blocks = [
      "0.0.0.0/0"
    ]
    # Configure allowed egress protocols and ports for fine-grained control
    allowed_egress_protocols = {
      http_https = true   # needed for package updates and API calls
      dns_tcp    = true   # Needed for DNS resolution
      dns_udp    = true   # Needed for DNS resolution
      ntp        = true   # Needed for time synchronization (logging accuracy)
      smtp       = false  # Not needed for this application
      custom_tcp = []     # Add custom ports if necessary
      custom_udp = []
    }

    # Enable/Disable SSH access via IAP for GDPR/HIPAA compliance
    allow_ssh_from_iap = false

  }
  egress         = {
    nat_name       = "test-vpc-nat"
    router_name    = "test-vpc-router"
  }
  ingress        = {
    instances         = [for vm in module.vm_nginx : vm.instance_self_link]  # Add the VM instances
    domains           = ["api.test.novahumana.io"]
    # Configure the health check for the backend service
    health_check_config = {
      port         = 80
      request_path = "/"
      protocol     = "HTTP"
    }
  }
}

# Import the custom VM/nginx module to create N VM instances running an Nginx web server
module "vm_nginx" {
  source = "./modules/compute/vm/nginx"
  count = 1 # create a single instance

  name             = "helloworld-${count.index + 1}"
  machine_type     = var.machine_type
  gcp_region       = var.gcp_region
  # Distribute instances across available zones for high availability. This operation uses the modulo operator to cycle through the list of available zones
  # and assign each instance to a different zone in round-robin fashion.
  gcp_zone         = data.google_compute_zones.available.names[count.index % length(data.google_compute_zones.available.names)]

  boot_disk_image  = data.google_compute_image.debian_11.self_link
  network_name     = module.network.network_name
  subnet_name      = module.network.subnets_names[0] # assign to the first subnet created in the VPC
  tags             = [
    # Apply the network tag to associate with the vpc module
    local.tags.vpc_egress, 
    # Apply the web_firewall tag to associate with the firewall rules created in the web_firewall module
    local.tags.web_firewall
  ]
}