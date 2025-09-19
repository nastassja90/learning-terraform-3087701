terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
  }
}

# GCP requires to define the project and region in the provider block, unlike AWS where the region is enough.
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}