# Use the VPC module to create a VPC with a subnet and custom routes
module "vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 12.0"

    project_id   = var.gcp_project_id
    network_name = var.vpc.network_name
    # GLOBAL: routes are applied to all subnets in the VPC, regardless of the region
    # REGIONAL: routes are applied only to subnets in the same region as the route
    routing_mode = var.vpc.routing_mode

    subnets = [for subnet in var.vpc.subnets :
        # We start defining a single subnet in the VPC, we can add more later if needed
        {
            # general config for the subnet
            subnet_name                = subnet.name
            subnet_ip                  = subnet.ip
            subnet_region              = var.gcp_region
            # Enable Private Google Access for this subnet; 
            # in this way, VM without public IP can reach Google APIs and GCP services
            subnet_private_access      = true  

            # enable logging for this subnet
            subnet_flow_logs           = true # Enable VPC Flow Logs
            subnet_flow_logs_interval  = "INTERVAL_5_SEC"       # sets the aggregation interval for collecting flow logs (default: 5 seconds)
            subnet_flow_logs_sampling  = 1.0                    # 100% sampling set the sampling rate of VPC flow logs within the subnetwork
            subnet_flow_logs_metadata  = "INCLUDE_ALL_METADATA" # configures whether metadata fields should be added to the reported VPC flow logs
        }
    ]

    routes = var.vpc.routes
}

# Import the custom firewall module to create firewall rules for the web server
module "web_firewall" {
  source = "./firewall"

  firewall_name = var.firewall.name
  network_name  = module.vpc.network_name
  network_self_link  = module.vpc.network_self_link
  target_tag    = var.firewall.target_tag
  # Configure CIDR blocks allowed to access the web server
  # Since we use a LB to manage ingress traffic,
  # we need to allow a specific set of GCP IPs, because the LB is managed by GCP and uses these IP ranges to forward traffic to the backend VMs.
  allowed_ingress_cidr_blocks = var.firewall.allowed_ingress_cidr_blocks

  # Configure CIDR blocks allowed for egress traffic; for now we allow all outbound traffic, but this should be restricted in a production environment
  allowed_egress_cidr_blocks = var.firewall.allowed_egress_cidr_blocks
  # Configure allowed egress protocols and ports for fine-grained control
  allowed_egress_protocols = var.firewall.allowed_egress_protocols

  # Enable/Disable SSH access via IAP for GDPR/HIPAA compliance
  allow_ssh_from_iap = var.firewall.allow_ssh_from_iap
}

# Import the custom egress module to create Cloud NAT for controlled outbound traffic
module "egress" {
  source = "./egress"

  nat_name     = var.egress.nat_name
  router_name  = var.egress.router_name
  gcp_region   = var.gcp_region
  network_id   = module.vpc.network_id
}

# Import the custom ingress module to create a Load Balancer in front of the web server
module "ingress" {
  source = "./ingress"

  network_name      = module.vpc.network_name
  network_self_link = module.vpc.network_self_link
  gcp_region        = var.gcp_region
  gcp_zone          = var.gcp_zone
  instances         = var.ingress.instances
  domains           = var.ingress.domains
  # Configure the health check for the backend service
  health_check_config = var.ingress.health_check_config
}