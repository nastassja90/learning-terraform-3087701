##################################################################
# Ingress configuration for GDPR/HIPAA compliance                #
##################################################################

locals {
  # Define a local variable to choose between network_name and network_self_link. 
  # If network_self_link is provided, use it; otherwise, use network_name as a fallback.
  # The coalesce function returns the first non-null argument.
  network = coalesce(var.network_self_link, var.network_name)

  # Define a dynamic list of all allowed TCP egress protocols and ports
  egress_tcp_ports = concat(
    var.allowed_egress_protocols.http_https ? ["80", "443"] : [],
    var.allowed_egress_protocols.dns_tcp ? ["53"] : [],
    var.allowed_egress_protocols.smtp ? ["25", "587"] : [],
    var.allowed_egress_protocols.custom_tcp
  )

  # Define a dynamic list of all allowed UDP egress protocols and ports
  egress_udp_ports = concat(
    var.allowed_egress_protocols.dns_udp ? ["53"] : [],
    var.allowed_egress_protocols.ntp ? ["123"] : [],
    var.allowed_egress_protocols.custom_udp
  )
}

# Create firewall rule for HTTP traffic (equivalent to AWS ingress rule on port 80)
# This ingress rule also supports health checks from the Load Balancer
resource "google_compute_firewall" "web_http_ingress" {
  name    = "${var.firewall_name}-http-ingress"
  network = local.network
  direction = "INGRESS"
  priority = 1000
  
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
  priority = 1000
  
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

# Create firewall rule to allow SSH access only through Identity-Aware Proxy (IAP) for GDPR/HIPAA compliance
resource "google_compute_firewall" "web_ssh_iap_ingress" {
  count = var.allow_ssh_from_iap ? 1 : 0
  
  name     = "${var.firewall_name}-ssh-iap-ingress"
  network  = local.network
  priority = 900  # higher priority than the deny rule
  direction = "INGRESS"
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  # Google Identity-Aware Proxy IP range
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.target_tag]
  
  description = "Allow SSH only through Identity-Aware Proxy for audit trail"
  
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Add explicit SSH deny rule for GDPR/HIPAA compliance in the ingress direction
resource "google_compute_firewall" "web_ssh_deny_ingress" {
  name     = "${var.firewall_name}-ssh-deny-ingress"
  network  = local.network
  direction = "INGRESS"
  priority = 999
  
  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = ["0.0.0.0/0"] # Deny SSH from all sources
  target_tags   = [var.target_tag]
  
  description = "Explicitly deny all SSH access attempts"
  
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
  
  description = "Deny all ingress traffic with logging"
}

##################################################################
# Egress configuration for GDPR/HIPAA compliance                 #
##################################################################

# Create firewall rule for allowed outbound TCP traffic (equivalent to AWS egress rule)
resource "google_compute_firewall" "web_allow_egress_tcp" {
  count = length(local.egress_tcp_ports) > 0 ? 1 : 0
  
  name      = "${var.firewall_name}-allow-egress-tcp"
  network   = local.network
  direction = "EGRESS"
  priority  = 1000
  
  # Enable only necessary protocols and ports for outbound traffic
  allow {
    protocol = "tcp"
    ports    = local.egress_tcp_ports
  }
  
  # Allow outbound traffic to specific CIDR blocks (e.g., SaaS providers, CDNs). In this case we allow 
  # to connect to any IP. For a more secure setup, replace with specific CIDR blocks of your SaaS providers.
  destination_ranges = var.allowed_egress_cidr_blocks
  # notice how the target_tags are used to bind the rule to the instances with the same tag
  target_tags        = [var.target_tag]
  
  description = "Allow specific TCP egress traffic to approved destinations"

  # enable logging for audit purposes (GDPR/HIPAA compliance)
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Create firewall rule for allowed outbound UDP traffic (equivalent to AWS egress rule)
resource "google_compute_firewall" "web_allow_egress_udp" {
  count = length(local.egress_udp_ports) > 0 ? 1 : 0
  
  name      = "${var.firewall_name}-allow-egress-udp"
  network   = local.network
  direction = "EGRESS"
  priority  = 1000
  
  allow {
    protocol = "udp"
    ports    = local.egress_udp_ports
  }
  
  destination_ranges = var.allowed_egress_cidr_blocks
  target_tags        = [var.target_tag]
  
  description = "Allow specific UDP egress traffic to approved destinations"

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Create firewall rule to allow HTTPS traffic to Google APIs via Private Google Access
resource "google_compute_firewall" "web_allow_egress_google_apis" {
  name      = "${var.firewall_name}-allow-egress-google-apis"
  network   = local.network
  direction = "EGRESS"
  priority  = 900
  
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  
  # Private Google Access IP ranges
  destination_ranges = [
    "199.36.153.8/30",    # private.googleapis.com
    "199.36.153.4/30"     # restricted.googleapis.com
  ]
  target_tags        = [var.target_tag]
  
  description = "Allow HTTPS to Google APIs via Private Google Access"

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
  
  description = "Deny all egress traffic with logging"
}