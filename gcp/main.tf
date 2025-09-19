# Output available zones in the selected region
data "google_compute_zones" "available" {
  region = var.gcp_region
}

# GCP does not use filters to search for images, but you can either use the image name or the image family.
# The image family is a way to group images, and when you use it, GCP will always return the latest non-deprecated image in that family.
# In this case, we are using the "debian-11" family from the "debian-cloud" project, which will always return the latest Debian 11 image available.
# This is equivalent to using filters in AWS to always get the latest version of an AMI.
data "google_compute_image" "debian_11" {
  family  = "debian-11" # in the AWS example we are deploying a Bitnami Tomcat image, but for simplicity we are using a common Debian image here
  project = "debian-cloud"
}

# GCP follows a different approach compared to AWS, since it requires to be explicit 
# about the boot disk and networking configurations. When creating a new EC2 instance on AWS, you can skip networking, storage and IP configurations, since
# AWS will create them with default values. However, on GCP we need to always define all these low-level details explicitly.
resource "google_compute_instance" "web" {
  name         = "helloworld"
  machine_type = var.machine_type
  zone         = data.google_compute_zones.available.names[0]  # Take the first available zone in the selected region

  # Define the storage (boot disk) configuration
  boot_disk {
    auto_delete = true # Delete the disk when the VM instance is deleted
    initialize_params {
      image = data.google_compute_image.debian_11.self_link
    }
  }

  # Define the networking configuration
  network_interface {
    network = "default"
    access_config {
      # Ephemeral external IP; this avoids the need to create a static IP address that costs money.
    }
  }

  labels = {
    name = "helloworld"
  }
}