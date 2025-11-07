##################################################################
# Ingress configuration for GDPR/HIPAA compliance                #
##################################################################

locals {
  # Define a local variable to choose between network_name and network_self_link. 
  # If network_self_link is provided, use it; otherwise, use network_name as a fallback.
  # The coalesce function returns the first non-null argument.
  network = coalesce(var.network_self_link, var.network_name)
}

# Create firewall rule for HTTP traffic (equivalent to AWS ingress rule on port 80)
resource "google_compute_firewall" "web_http_ingress" {
  name    = "${var.firewall_name}-http-ingress"
  network = local.network
  direction = "INGRESS"
  
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  
  source_ranges = var.allowed_ingress_cidr_blocks
  # notice how the target_tags are used to bind the rule to the instances with the same tag
  target_tags   = [var.target_tag]
  
  description = "Allow HTTP traffic from specified CIDR blocks"  

  # enable logging for audit purposes (GDPR/HIPAA compliance)
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Create firewall rule for HTTPS traffic (equivalent to AWS ingress rule on port 443)
resource "google_compute_firewall" "web_https_ingress" {
  name    = "${var.firewall_name}-https-ingress"
  network = local.network
  direction = "INGRESS"
  
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  
  source_ranges = var.allowed_ingress_cidr_blocks
  # notice how the target_tags are used to bind the rule to the instances with the same tag
  target_tags   = [var.target_tag]
  
  description = "Allow HTTPS traffic from specified CIDR blocks"

  # enable logging for audit purposes (GDPR/HIPAA compliance)
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Add explicit SSH deny rule for GDPR/HIPAA compliance in the ingress direction
resource "google_compute_firewall" "web_ssh_deny_ingress" {
  name     = "${var.firewall_name}-ssh-deny-ingress"
  network  = local.network
  priority = 999
  direction = "INGRESS"
  
  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = ["0.0.0.0/0"] # Deny SSH from all sources
  target_tags   = [var.target_tag]
  
  description = "GDPR/HIPAA: Explicitly deny all SSH access attempts"
  
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# This rule denies all ingress traffic not explicitly allowed above, with logging enabled for audit purposes.
resource "google_compute_firewall" "web_deny_ingress" {
  name     = "${var.firewall_name}-deny-ingress"
  network  = local.network
  priority = 65534
  direction = "INGRESS"
  
  deny {
    protocol = "all"
  }
  
  source_ranges = ["0.0.0.0/0"] # Deny all sources
  
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  target_tags   = [var.target_tag]
  
  description = "GDPR/HIPAA: Deny all ingress traffic with logging"
}

# Create firewall rules to allow health checks from Google Cloud Load Balancer
# Health check traffic comes from specific IP ranges that need to be allowed
resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check"
  network = local.network

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Google Cloud Load Balancer health check IP ranges
  source_ranges = var.allowed_ingress_cidr_blocks

  # Apply the rule to instances with the specified target tag
  target_tags = [var.target_tag]

  description = "Allow health check traffic from Google Cloud Load Balancer"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

##################################################################
# Egress configuration for GDPR/HIPAA compliance                 #
##################################################################

# Create firewall rule for allowed outbound traffic (equivalent to AWS egress rule)
resource "google_compute_firewall" "web_allow_egress" {
  name      = "${var.firewall_name}-allow-egress"
  network   = local.network
  direction = "EGRESS"
  
  # Enable only necessary protocols and ports for outbound traffic
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]  # HTTP/HTTPS 
  }
  
  allow {
    protocol = "tcp"
    ports    = ["53"]         # DNS TCP
  }
  
  allow {
    protocol = "udp"
    ports    = ["53", "123"]  # DNS UDP e NTP
  }
  
  # Allow outbound traffic to specific CIDR blocks (e.g., SaaS providers, CDNs). In this case we allow 
  # to connect to any IP. For a more secure setup, replace with specific CIDR blocks of your SaaS providers.
  destination_ranges = var.allowed_egress_cidr_blocks
  # notice how the target_tags are used to bind the rule to the instances with the same tag
  target_tags        = [var.target_tag]
  
  description = "Allow all outbound traffic to specified CIDR blocks"

  # enable logging for audit purposes (GDPR/HIPAA compliance)
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# This rule denies all egress traffic not explicitly allowed above, with logging enabled for audit purposes.
resource "google_compute_firewall" "web_deny_egress" {
  name     = "${var.firewall_name}-deny-egress"
  network  = local.network
  priority = 65534
  direction = "EGRESS"
  
  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"] # Deny all destinations

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  target_tags   = [var.target_tag]
  
  description = "GDPR/HIPAA: Deny all egress traffic with logging"
}