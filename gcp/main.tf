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

# Use the VPC module to create a VPC with a subnet and custom routes
module "vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 12.0"

    project_id   = var.gcp_project_id
    network_name = "test-vpc"
    # GLOBAL: routes are applied to all subnets in the VPC, regardless of the region
    # REGIONAL: routes are applied only to subnets in the same region as the route
    routing_mode = "GLOBAL"

    subnets = [
        # We start defining a single subnet in the VPC, we can add more later if needed
        {
            # general config for the subnet
            subnet_name                = "subnet-01"
            subnet_ip                  = "10.10.10.0/24"
            subnet_region              = var.gcp_region
            # Enable Private Google Access for this subnet; 
            # in this way, VM without public IP can reach Google APIs and GCP services
            subnet_private_access      = true  

            # enable logging for this subnet
            subnet_flow_logs           = true # Enable VPC Flow Logs
            subnet_flow_logs_interval  = "INTERVAL_5_SEC"       # sets the aggregation interval for collecting flow logs (default: 5 seconds)
            subnet_flow_logs_sampling  = 1.0                    # 100% sampling set the sampling rate of VPC flow logs within the subnetwork
            subnet_flow_logs_metadata  = "INCLUDE_ALL_METADATA" # configures whether metadata fields should be added to the reported VPC flow logs
        },
    ]

    # Use custom routes to better control egress traffic from the VPC and assign routes to specific VM using network tags.
    # This pattern allows to increase security and compliance. By default, GCP creates an automatic route to allow all VM in the VPC to access internet,
    # this is not compliant with GDPR/HIPAA regulations, since you cannot control which VM can access internet and which cannot.
    routes = [
        {
            name                   = "egress-internet"
            description            = "route through IGW to access internet"
            destination_range      = "0.0.0.0/0"
            tags                   = "egress-inet"
            # the next hop to this route will be the default internet gateway
            next_hop_internet      = "true"
            priority               = 1000
        },
    ]
}

# Import the custom firewall module to create firewall rules for the web server
module "web_firewall" {
  source = "./modules/firewall"
  
  firewall_name = "web-firewall"
  network_name  = module.vpc.network_name
  network_self_link  = module.vpc.network_self_link
  target_tag    = "web-firewall-compliant"
  # Configure CIDR blocks allowed to access the web server
  # Since we use a LB to manage ingress traffic,
  # we need to allow a specific set of GCP IPs, because the LB is managed by GCP and uses these IP ranges to forward traffic to the backend VMs.
  allowed_ingress_cidr_blocks = ["35.191.0.0/16", "130.211.0.0/22"]
}

# Import the custom VM/nginx module to create N VM instances running an Nginx web server
module "vm_nginx" {
  source = "./modules/vm/nginx"
  count = 1 # create a single instance

  name             = "helloworld-${count.index + 1}"
  machine_type     = var.machine_type
  gcp_region       = var.gcp_region
  # Distribute instances across available zones for high availability. This operation uses the modulo operator to cycle through the list of available zones
  # and assign each instance to a different zone in round-robin fashion.
  gcp_zone         = data.google_compute_zones.available.names[count.index % length(data.google_compute_zones.available.names)]

  boot_disk_image  = data.google_compute_image.debian_11.self_link
  network_name     = module.vpc.network_name
  subnet_name      = module.vpc.subnets_names[0]
  tags             = [
    # Apply the network tag to associate with the vpc module
    "egress-inet", 
    # Apply the web_firewall tag to associate with the firewall rules created in the web_firewall module
    module.web_firewall.target_tag
  ]
}

# Import the custom egress module to create Cloud NAT for controlled outbound traffic
module "egress" {
  source = "./modules/egress"

  nat_name     = "test-vpc-nat"
  router_name  = "test-vpc-router"
  gcp_region   = var.gcp_region
  network_id   = module.vpc.network_id
}

# Import the custom ingress module to create a Load Balancer in front of the web server
module "ingress" {
  source = "./modules/ingress"

  network_name      = module.vpc.network_name
  network_self_link = module.vpc.network_self_link
  gcp_region        = var.gcp_region
  gcp_zone          = data.google_compute_zones.available.names[0]  # Use the first available zone in the selected region
  instances         = [
    for vm in module.vm_nginx : vm.instance_self_link
  ]  # Add the VM instances
  domains           = ["api.test.novahumana.io"]
  # Configure the health check for the backend service
  health_check_config = {
    port         = 80
    request_path = "/"
    protocol     = "HTTP"
  }
}