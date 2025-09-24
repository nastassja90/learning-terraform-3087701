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

variable "target_tag" {
  description = "Network tag to apply firewall rules to instances"
  type        = string
  default     = "web-server"
}

variable "allowed_ingress_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_egress_cidr_blocks" {
  description = "List of CIDR blocks allowed to be accessed by the resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}