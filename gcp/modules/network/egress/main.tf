# Configure Cloud Router to enable Cloud NAT for the VPC; in this way all outbound traffic from VM
# deployed inside the VPC will exit with the public IP of the NAT gateway, allowing to control and log all outbound traffic.
# This is a common requirement for GDPR/HIPAA compliance, since it allows to have an audit trail of all outbound traffic from the VPC using always the same IP address.
resource "google_compute_router" "vpc_router" {
  name    = var.router_name
  region  = var.gcp_region
  network = var.network_id

  bgp {
    asn = 64514
  }
}

# Cloud NAT for controlled outbound traffic (GDPR/HIPAA requirement); use the Cloud router component
# configured above to create a NAT gateway for the VPC.
resource "google_compute_router_nat" "vpc_nat" {
  name                               = var.nat_name
  router                             = google_compute_router.vpc_router.name
  region                             = var.gcp_region
  nat_ip_allocate_option            = "AUTO_ONLY"
  
  # Possible values: 
  # -- ALL_SUBNETWORKS_ALL_IP_RANGES: NAT for all subnets and all IP ranges (primary and secondary)
  # -- ALL_SUBNETWORKS_PRIMARY_IP_RANGES: NAT for all subnets but only primary IP ranges
  # -- LIST_OF_SUBNETWORKS: NAT only for specific subnets (it depends on subnetwork_names parameter)
  source_subnetwork_ip_ranges_to_nat    = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  # Logging per compliance GDPR/HIPAA
  log_config {
    enable = true
    filter = "ALL"
  }
  
  # Endpoint mapping to monitor traffic
  endpoint_types = ["ENDPOINT_TYPE_VM"]
}