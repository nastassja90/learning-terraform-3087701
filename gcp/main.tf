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
  allowed_ingress_cidr_blocks = ["0.0.0.0/0"]
}

# Import the custom egress module to create Cloud NAT for controlled outbound traffic
module "egress" {
  source = "./modules/egress"

  nat_name     = "test-vpc-nat"
  router_name  = "test-vpc-router"
  gcp_region   = var.gcp_region
  network_id   = module.vpc.network_id
}

# GCP follows a different approach compared to AWS, since it requires to be explicit 
# about the boot disk and networking configurations. When creating a new EC2 instance on AWS, you can skip networking, storage and IP configurations, since
# AWS will create them with default values. However, on GCP we need to always define all these low-level details explicitly.
resource "google_compute_instance" "web" {
  name         = "helloworld"
  machine_type = var.machine_type
  zone         = data.google_compute_zones.available.names[0]  # Take the first available zone in the selected region

  # Define the storage (boot disk) configuration
  boot_disk {
    auto_delete = true # Delete the disk when the VM instance is deleted
    initialize_params {
      image = data.google_compute_image.debian_11.self_link
    }
  }

  # Define the networking configuration
  network_interface {
    network    = module.vpc.network_name        # use the test-vpc network"
    subnetwork = module.vpc.subnets_names[0]    # use the first subnet created in the vpc module
  }

  # Enable Shielded VM for better security (GDPR/HIPAA requirement)
  # This is an advanced security feature provided by GCP to protect VM from rootkits and bootkits and other malware.
  shielded_instance_config {
    # Enable Secure Boot to ensure only trusted code is executed during the boot process
    enable_secure_boot          = true
    # Enable the TSM (Trusted Platform Module) to securely store cryptographic keys
    enable_vtpm                = true
    # Enable Integrity Monitoring to detect and report any changes to the VM's boot integrity
    enable_integrity_monitoring = true
  }

  # Disable the default display device to reduce the attack surface
  # (not strictly required for GDPR/HIPAA, but a good security practice)
  enable_display = false

  metadata = {
    # Enable OS Login for better security (GDPR/HIPAA requirement). This allows to manage SSH access 
    # using IAM roles instead of managing SSH keys manually. It also provides better auditing and logging capabilities.
    enable-oslogin = "TRUE"
    # Block project-wide SSH keys to enforce OS Login usage; each user must use their own IAM role to access the VM via SSH
    # it is not possible to use project-wide SSH keys anymore.
    block-project-ssh-keys = "TRUE"
  }

  # Startup script to install and start Nginx web server on boot
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt update
    apt install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Hello from GCP!</h1>" > /var/www/html/index.html
  EOF

  tags = [
    # Apply the network tag to associate with the vpc module
    "egress-inet", 
    # Apply the web_firewall tag to associate with the firewall rules created in the web_firewall module
    module.web_firewall.target_tag
  ]

  labels = {
    name = "helloworld"
  }
}