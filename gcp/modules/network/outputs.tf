# Output the ID of the VPC network
output "network_id" {
  description = "Id of the VPC network"
  value       = module.vpc.network_id
}

# Output the name of the VPC network
output "network_name" {
  description = "Name of the VPC network"
  value       = module.vpc.network_name
}

# Output the self link of the VPC network
output "network_self_link" {
  description = "Self link of the VPC network"
  value       = module.vpc.network_self_link
}

# Output the list of subnet IDs created in the VPC
output "subnets_names" {
  description = "List of subnet names created in the VPC"
  value       = module.vpc.subnets_names
}

# Output applied firewall rules
output "firewall_rules" {
  description = "List of firewall rules applied in the VPC"
  value       = {
    rules = module.web_firewall.firewall_rules
    allowed_ingress_cidrs = module.web_firewall.allowed_ingress_cidrs
    allowed_egress_cidrs  = module.web_firewall.allowed_egress_cidrs
    effective_egress_ports = module.web_firewall.effective_egress_ports
  }
}

# Output the Load Balancer IP address - this is the IP you need to configure in your DNS A record
output "load_balancer_ip" {
  description = "The external IP address of the Load Balancer - Configure this IP as an A record for your managed domains"
  value       = module.ingress.load_balancer_ip
}

# Output the SSL certificate status
output "ssl_certificate_status" {
  description = "Status of the managed SSL certificate - It may take several minutes to provision after DNS is configured"
  value       = module.ingress.ssl_certificate_status
}