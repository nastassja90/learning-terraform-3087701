variable "network_name" {
  description = "Name of the VPC network attached to the load balancer"
  type        = string
  default     = "default"
}

variable "network_self_link" {
  description = "Self link of the VPC network attached to the load balancer"
  type        = string
  default     = null
}

variable "gcp_region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "europe-west1" # This is the equivalent of eu-west-1 in AWS
}

variable "gcp_zone" {
  description = "The GCP zone where resources will be created"
  type        = string
  default     = null
}

variable "instances" {
  description = "List of instance self_links to be added to the instance group"
  type        = list(string)
  default     = []
}

variable "domains" {
    description = "List of domains for the managed SSL certificate"
    type        = list(string)
    default     = []
}

variable "health_check_config" {
  description = "Configuration for the health check"
  type = object({
    port         = number
    request_path = string
    protocol     = string  # "HTTP" or "HTTPS"
  })
  default = {
    port         = 80
    request_path = "/"
    protocol     = "HTTP"
  }
}