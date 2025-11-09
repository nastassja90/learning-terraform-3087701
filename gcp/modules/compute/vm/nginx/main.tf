# GCP follows a different approach compared to AWS, since it requires to be explicit
# about the boot disk and networking configurations. When creating a new EC2 instance on AWS, you can skip networking, storage and IP configurations, since
# AWS will create them with default values. However, on GCP we need to always define all these low-level details explicitly.
resource "google_compute_instance" "nginx" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.gcp_zone

  # Define the storage (boot disk) configuration
  boot_disk {
    auto_delete = true # Delete the disk when the VM instance is deleted
    initialize_params {
      image = var.boot_disk_image
    }
  }

  # Define the networking configuration
  network_interface {
    network    = var.network_name # use the test-vpc network"
    subnetwork = var.subnet_name # use the first subnet created in the vpc module
  }

  # Enable Shielded VM for better security (GDPR/HIPAA requirement)
  # This is an advanced security feature provided by GCP to protect VM from rootkits and bootkits and other malware.
  shielded_instance_config {
    # Enable Secure Boot to ensure only trusted code is executed during the boot process
    enable_secure_boot          = true
    # Enable the TSM (Trusted Platform Module) to securely store cryptographic keys
    enable_vtpm                = true
    # Enable Integrity Monitoring to detect and report any changes to the VM's boot integrity
    enable_integrity_monitoring = true
  }

  # Disable the default display device to reduce the attack surface
  # (not strictly required for GDPR/HIPAA, but a good security practice)
  enable_display = false

  metadata = {
    # Enable OS Login for better security (GDPR/HIPAA requirement). This allows to manage SSH access 
    # using IAM roles instead of managing SSH keys manually. It also provides better auditing and logging capabilities.
    enable-oslogin = "TRUE"
    # Block project-wide SSH keys to enforce OS Login usage; each user must use their own IAM role to access the VM via SSH
    # it is not possible to use project-wide SSH keys anymore.
    block-project-ssh-keys = "TRUE"
  }

  # Startup script to install and start Nginx web server on boot
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt update
    apt install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Hello from GCP!</h1>" > /var/www/html/index.html
  EOF

  tags = var.tags

  labels = {
    name = var.name
  }
}