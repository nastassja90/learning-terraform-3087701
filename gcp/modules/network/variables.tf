variable "gcp_project_id" {
  description = "The GCP Project ID where resources will be created"
  type        = string
}

variable "gcp_region" {
  description = "The GCP region where resources will be created"
  type        = string
}

variable "gcp_zone" {
  description = "The GCP zone where resources will be created"
  type        = string
}

variable "ingress" {
    description = "Configurations for the ingress module"
    type        = object({
        domains             = list(string)
        instances           = list(string)
        health_check_config = object({
            port         = number
            request_path = string
            protocol     = string
        })
    })
}

variable "egress" {
    description = "Configurations for the egress module"
    type        = object({
        nat_name       = string
        router_name    = string
    })
}

variable "firewall" {
    description = "Configurations for the firewall module"
    type        = object({
        name                        = string
        target_tag                  = string
        allowed_ingress_cidr_blocks = list(string)
        allowed_egress_cidr_blocks  = list(string)
        allowed_egress_protocols    = object({
            http_https = bool
            dns_tcp    = bool
            dns_udp    = bool
            ntp        = bool
            smtp       = bool
            custom_tcp = list(number)
            custom_udp = list(number)
        })
        allow_ssh_from_iap          = bool
    })
}

variable "vpc" {
    description = "Configurations for the VPC module"
    type        = object({
        network_name       = string
        routing_mode       = string
        subnets            = list(object({
            name = string
            ip   = string
            region = string
        }))
        routes            = list(object({
            name              = string
            description       = string
            destination_range = string
            tags              = list(string)
            next_hop_internet = string
            priority          = number
        }))
    })
}