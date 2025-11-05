output "target_tag" {
  description = "Network tag used for targeting instances"
  value       = var.target_tag
}

output "firewall_rules" {
  description = "Created firewall rule names"
  value = [
    google_compute_firewall.web_http_ingress.name,
    google_compute_firewall.web_https_ingress.name,
    google_compute_firewall.web_ssh_deny_ingress.name,
    google_compute_firewall.web_deny_ingress.name,
    google_compute_firewall.web_allow_egress.name,
    google_compute_firewall.web_deny_egress.name
  ]
}