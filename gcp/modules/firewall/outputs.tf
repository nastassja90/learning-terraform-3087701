output "firewall_http_name" {
  description = "Name of the HTTP firewall rule"
  value       = google_compute_firewall.web_http_in.name
}

output "firewall_https_name" {
  description = "Name of the HTTPS firewall rule"
  value       = google_compute_firewall.web_https_in.name
}

output "firewall_egress_name" {
  description = "Name of the egress firewall rule"
  value       = google_compute_firewall.web_everything_out.name
}

output "target_tag" {
  description = "Network tag used for targeting instances"
  value       = var.target_tag
}