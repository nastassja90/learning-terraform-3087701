data "google_compute_image" "app_image" {
  most_recent = true
  
  filter {
    name   = "name"
    values = ["bitnami-tomcat-*"]
  }
  
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