# Custom firewall module

This Terraform module is an example that shows how to manually create a set of firewall rules on GCP, which are the equivalent of a security group with custom rules on AWS. This module has been created from scratch, starting from the minimal building blocks required as resources to define firewalls properly. In production when possible, it's better to use pre-made Terraform modules maintained by the community on the [Terraform registry](https://registry.terraform.io/).

## Usage

Import this module in the root `main.tf` as follows:

```terraform
# Import the module
module "web_firewall" {
  source = "./modules/firewall"

  firewall_name = "web"
  network_name  = "default"
  # The target tag is used to associate the firewall rules with the instances that have the same tag
  target_tag    = "web-server"
  allowed_ingress_cidr_blocks = ["0.0.0.0/0"]
  allowed_egress_cidr_blocks  = ["0.0.0.0/0"]
}
```

Then reference the module's tags in all resources that need it:

```terraform
resource "google_compute_instance" "web" {
  name         = "helloworld"
  machine_type = var.machine_type
  zone         = data.google_compute_zones.available.names[0]

  # Define the storage (boot disk) configuration
  boot_disk {
    ...
  }

  # Define the networking configuration
  network_interface {
    ...
  }

  # Apply the network tag to associate with firewall rules, so that the instance is affected by the firewall rules created in the module
  tags = [module.web_firewall.target_tag]
}
```
