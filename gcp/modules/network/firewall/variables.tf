variable "firewall_name" {
  description = "Base name for firewall rules"
  type        = string
  default     = "web"
}

variable "network_name" {
  description = "Name of the VPC network where firewall rules will be applied"
  type        = string
  default     = "default"
}

variable "network_self_link" {
  description = "Self link of the VPC network where firewall rules will be applied"
  type        = string
  default     = null
}

variable "target_tag" {
  description = "Network tag to apply firewall rules to instances"
  type        = string
  default     = "web-server"
}

variable "allowed_ingress_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the resources"
  type        = list(string)

  # Validate at least one CIDR block is provided
  validation {
    condition     = length(var.allowed_ingress_cidr_blocks) > 0
    error_message = "At least one CIDR block must be specified for ingress traffic."
  }

  # Validate each CIDR block is valid
  validation {
    condition = alltrue([
      for cidr in var.allowed_ingress_cidr_blocks : 
      can(cidrhost(cidr, 0))
    ])
    error_message = "All elements must be valid CIDR blocks (e.g., 10.0.0.0/8, 192.168.1.0/24)."
  }

  # Validate that CIDR block is not 0.0.0.0/0 for security reasons
  validation {
    condition     = !contains(var.allowed_ingress_cidr_blocks, "0.0.0.0/0")
    error_message = "SECURITY RISK: 0.0.0.0/0 is not allowed for ingress. Use specific IP ranges or implement Cloud Armor for DDoS protection. For GCP Load Balancers, use: ['35.191.0.0/16', '130.211.0.0/22']"
  }
}

variable "allowed_egress_cidr_blocks" {
  description = "List of CIDR blocks allowed for egress traffic"
  type        = list(string)

  # Validate at least one CIDR block is provided
  validation {
    condition     = length(var.allowed_egress_cidr_blocks) > 0
    error_message = "At least one egress destination must be specified."
  }

  # Validate each CIDR block is valid
  validation {
    condition = alltrue([
      for cidr in var.allowed_egress_cidr_blocks : 
      can(cidrhost(cidr, 0))
    ])
    error_message = "All elements must be valid CIDR blocks."
  }
  
  # ⚠️ Warning for 0.0.0.0/0 CIDR block (not forbidden, but a warning)
  # For production, consider enabling this validation:
  # validation {
  #   condition     = !contains(var.allowed_egress_cidr_blocks, "0.0.0.0/0")
  #   error_message = "WARNING: 0.0.0.0/0 egress detected. For production, restrict to specific destinations for GDPR/HIPAA compliance."
  # }
}

# variable for fine-grained control for egress protocols
variable "allowed_egress_protocols" {
  description = "Map of protocols and ports allowed for egress traffic"
  type = object({
    http_https = bool
    dns_tcp    = bool
    dns_udp    = bool
    ntp        = bool
    smtp       = bool  # for email sending
    custom_tcp = list(string)
    custom_udp = list(string)
  })
  default = {
    http_https = true
    dns_tcp    = true
    dns_udp    = true
    ntp        = true
    smtp       = false
    custom_tcp = []
    custom_udp = []
  }
}

# variable to control SSH access via IAP
variable "allow_ssh_from_iap" {
  description = "Allow SSH access through Identity-Aware Proxy (IAP). Recommended for GDPR/HIPAA compliance instead of direct SSH."
  type        = bool
  default     = false
}