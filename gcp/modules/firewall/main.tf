# Create firewall rule for HTTP traffic (equivalent to AWS ingress rule on port 80)
resource "google_compute_firewall" "web_http_in" {
  name    = "${var.firewall_name}-http-in"
  network = var.network_name
  
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  
  source_ranges = var.allowed_ingress_cidr_blocks
  # notice how the target_tags are used to bind the rule to the instances with the same tag
  target_tags   = [var.target_tag]
  
  description = "Allow HTTP traffic from specified CIDR blocks"
  
  labels = var.labels
}

# Create firewall rule for HTTPS traffic (equivalent to AWS ingress rule on port 443)
resource "google_compute_firewall" "web_https_in" {
  name    = "${var.firewall_name}-https-in"
  network = var.network_name
  
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  
  source_ranges = var.allowed_ingress_cidr_blocks
  # notice how the target_tags are used to bind the rule to the instances with the same tag
  target_tags   = [var.target_tag]
  
  description = "Allow HTTPS traffic from specified CIDR blocks"
  
  labels = var.labels
}

# Create firewall rule for all outbound traffic (equivalent to AWS egress rule)
resource "google_compute_firewall" "web_everything_out" {
  name      = "${var.firewall_name}-egress-all"
  network   = var.network_name
  direction = "EGRESS"
  
  allow {
    protocol = "all"
  }
  
  destination_ranges = var.allowed_egress_cidr_blocks
  # notice how the target_tags are used to bind the rule to the instances with the same tag
  target_tags        = [var.target_tag]
  
  description = "Allow all outbound traffic to specified CIDR blocks"
  
  labels = var.labels
}