# Output the Load Balancer IP address - this is the IP you need to configure in your DNS A record
output "load_balancer_ip" {
  description = "The external IP address of the Load Balancer - Configure this IP as an A record for your managed domains"
  value       = google_compute_global_address.lb_ip.address
}

# Output the SSL certificate status
output "ssl_certificate_status" {
  description = "Status of the managed SSL certificate - It may take several minutes to provision after DNS is configured"
  value       = google_compute_managed_ssl_certificate.lb_cert.managed
}