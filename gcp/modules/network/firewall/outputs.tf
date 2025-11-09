output "target_tag" {
  description = "Network tag used for targeting instances"
  value       = var.target_tag
}

output "firewall_rules" {
  description = "Created firewall rule names"
  value = concat(
    [
      google_compute_firewall.web_http_ingress.name,
      google_compute_firewall.web_https_ingress.name,
      google_compute_firewall.web_ssh_deny_ingress.name,
      google_compute_firewall.web_deny_ingress.name,
      google_compute_firewall.web_deny_egress.name,
      google_compute_firewall.web_allow_egress_google_apis.name
    ],
    var.allow_ssh_from_iap ? [google_compute_firewall.web_ssh_iap_ingress[0].name] : [],
    length(local.egress_tcp_ports) > 0 ? [google_compute_firewall.web_allow_egress_tcp[0].name] : [],
    length(local.egress_udp_ports) > 0 ? [google_compute_firewall.web_allow_egress_udp[0].name] : []
  )
}

# Output variables for troubleshooting
output "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed for ingress (for audit purposes)"
  value       = var.allowed_ingress_cidr_blocks
}

output "allowed_egress_cidrs" {
  description = "CIDR blocks allowed for egress (for audit purposes)"
  value       = var.allowed_egress_cidr_blocks
}

output "effective_egress_ports" {
  description = "Effective egress ports configuration"
  value = {
    tcp = local.egress_tcp_ports
    udp = local.egress_udp_ports
  }
}