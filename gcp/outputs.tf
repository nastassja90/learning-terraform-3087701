#output "instance_image" {
#  value = google_compute_instance.web.boot_disk[0].initialize_params[0].image
#}

#output "instance_self_link" {
#  value = google_compute_instance.web.self_link
#}

#output "instance_external_ip" {
#  value = google_compute_instance.web.network_interface[0].access_config[0].nat_ip
#}

#output "instance_zone" {
#  value = google_compute_instance.web.zone
#}