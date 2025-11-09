# Output the Load Balancer IP address - this is the IP you need to configure in your DNS A record
output "load_balancer_ip" {
  description = "The external IP address of the Load Balancer - Configure this IP as an A record for your managed domains"
  value       = module.network.load_balancer_ip
}

# Output the SSL certificate status
output "ssl_certificate_status" {
  description = "Status of the managed SSL certificate - It may take several minutes to provision after DNS is configured"
  value       = module.network.ssl_certificate_status
}

# Output applied firewall rules
output "firewall_rules" {
  description = "List of firewall rules applied in the VPC"
  value       = module.network.firewall_rules
}