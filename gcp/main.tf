# GCP does not use filters to search for images, but you can either use the image name or the image family.
# The image family is a way to group images, and when you use it, GCP will always return the latest non-deprecated image in that family.
# In this case, we are using the "tomcat" family from the "bitnami-launchpad" project, which will always return the latest Tomcat image available.
# This is equivalent to using filters in AWS to always get the latest version of an AMI.
data "google_compute_image" "bitnami_tomcat" {
  family  = "tomcat"
  project = "bitnami-launchpad"
}

# GCP follows a different approach compared to AWS, since it requires to be explicit 
# about the boot disk and networking configurations. When creating a new EC2 instance on AWS, you can skip networking, storage and IP configurations, since
# AWS will create them with default values. However, on GCP we need to always define all these low-level details explicitly.
resource "google_compute_instance" "web" {
  name         = "helloworld"
  machine_type = var.machine_type
  zone         = "${var.gcp_region}-a"

  # Define the storage (boot disk) configuration
  boot_disk {
    initialize_params {
      image = data.google_compute_image.app_image.self_link
    }
  }

  # Define the networking configuration
  network_interface {
    network = "default"
    access_config {
      # Ephemeral external IP
    }
  }

  labels = {
    name = "helloworld"
  }
}