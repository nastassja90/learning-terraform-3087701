# outputs.tf defines the outputs for the root module. 
# Each Terraform module can have a list of inputs and outputs variables that can be used to customize 
# the module or to export values to be used by other components.

output "instance_image" {
 value = google_compute_instance.web.boot_disk[0].initialize_params[0].image
}

# In GCP the self_link is a unique identifier for the resource, similar to the ARN in AWS that can be used internally
# to reference the resource from the gcloud CLI, GCP APIs or other apps deployed on GCP via service accounts credentials. 
# This link is not meant to be accessible via browser.
output "instance_self_link" {
 value = google_compute_instance.web.self_link
}
