variable "machine_type" {
 description = "Type of GCP Compute Engine instance to provision"
 type        = string
 default     = "e2-micro" # This is the equivalent of t3.nano in AWS
}

variable "gcp_project_id" {
  description = "The GCP Project ID where resources will be created"
  type        = string
  default     = "novahumana-test"
}

variable "gcp_region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = "europe-west1" # This is the equivalent of eu-west-1 in AWS
}