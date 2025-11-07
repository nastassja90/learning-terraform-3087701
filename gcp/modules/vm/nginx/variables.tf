variable "name" {
  description = "Name of the VM instance"
  type        = string
  default     = "web-server"
}
variable "machine_type" {
  description = "Machine type of the VM instance"
  type        = string
  default     = "e2-medium" # 2 vCPU, 4 GB RAM
}

variable "gcp_region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "europe-west1" # This is the equivalent of eu-west-1 in AWS
}

variable "gcp_zone" {
  description = "The GCP zone where the VM instance will be created"
  type        = string
  default     = null
}

variable "boot_disk_image" {
  description = "The boot disk image for the VM instance"
  type        = string
  default     = "debian-cloud/debian-11" # Debian 11 image
}

variable "network_name" {
  description = "Name of the VPC network where the VM instance will be deployed"
  type        = string
  default     = "default"
}

variable "subnet_name" {
  description = "Name of the subnet where the VM instance will be deployed"
  type        = string
  default     = "default"
}

variable "tags" {
  description = "List of network tags to attach to the VM instance"
  type        = list(string)
  default     = []
}