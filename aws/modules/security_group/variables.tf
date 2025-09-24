variable "security_group_name" {
  description = "Name of the security group"
  type        = string
  default     = "blog"
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
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

variable "tags" {
  description = "Tags to apply to the security group"
  type        = map(string)
  default = {
    Terraform = "true"
  }
}