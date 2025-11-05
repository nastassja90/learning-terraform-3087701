variable "nat_name" {
  description = "Name of the Cloud NAT gateway"
  type        = string
  default     = "default"
}
variable "router_name" {
  description = "Name of the Cloud Router"
  type        = string
  default     = "default"
}

variable "gcp_region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "europe-west1" # This is the equivalent of eu-west-1 in AWS
}

variable "network_id" {
  description = "The VPC network id where the Cloud NAT will be attached"
  type        = string
  default     = "default"
}