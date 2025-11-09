##################################################################
# HTTPS Load Balancer Configuration                              #
##################################################################


locals {
  # Define a local variable to choose between network_name and network_self_link. 
  # If network_self_link is provided, use it; otherwise, use network_name as a fallback.
  # The coalesce function returns the first non-null argument.
  network = coalesce(var.network_self_link, var.network_name)
}


# Reserve a global static external IP address for the Load Balancer
resource "google_compute_global_address" "lb_ip" {
  name         = "lb-ip"
  address_type = "EXTERNAL"
}

# Create a managed SSL certificate for the custom domain
resource "google_compute_managed_ssl_certificate" "lb_cert" {
  name = "ssl-cert"

  managed {
    domains = var.domains
  }
}

# Create an unmanaged instance group (since we have a single instance, not an autoscaling group)
# The instance group is a logical container for the instances that will receive traffic from the Load Balancer.
# It's here that is defined the port that the Load Balancer will use to forward traffic to the instances.
resource "google_compute_instance_group" "web_group" {
  name        = "instance-group"
  description = "Instance group for the web server"
  zone        = var.gcp_zone

  instances = var.instances

  # Define the named port that the Load Balancer will use to forward traffic
  named_port {
    name = "http"
    port = 80
  }
}

# Create a health check to verify the instance is healthy
resource "google_compute_health_check" "web_health_check" {
  name                = "health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  dynamic "http_health_check" {
    for_each = var.health_check_config.protocol == "HTTP" ? [1] : []
    content {
      port         = var.health_check_config.port
      request_path = var.health_check_config.request_path
    }
  }

  dynamic "https_health_check" {
    for_each = var.health_check_config.protocol == "HTTPS" ? [1] : []
    content {
      port         = var.health_check_config.port
      request_path = var.health_check_config.request_path
    }
  }
}

# Create the backend service that groups instances and applies the health check.
# The backend service is responsible for directing traffic to the correct instance group; it also
# balances the load and performs health checks to ensure traffic is only sent to healthy instances.
resource "google_compute_backend_service" "web_backend" {
  name                  = "backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  health_checks         = [google_compute_health_check.web_health_check.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_instance_group.web_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Create a URL map to route incoming requests to the backend service,
# This resource represents the set of routing rules for the Load Balancer. It basically says
# to which backend service the traffic should be directed based on the URL patterns.
resource "google_compute_url_map" "web_url_map" {
  name            = "url-map"
  default_service = google_compute_backend_service.web_backend.id
}

# Create an HTTPS proxy that uses the SSL certificate.
# This resource represents the component that terminates SSL and forwards requests to the URL map.
# It uses the SSL certificate created earlier to handle HTTPS traffic and decrypt it before passing it to the backend service.
resource "google_compute_target_https_proxy" "web_https_proxy" {
  name             = "https-proxy"
  url_map          = google_compute_url_map.web_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb_cert.id]
}

# Create a global forwarding rule to route traffic from the external IP to the HTTPS proxy
# This represents the entrypoint for the Load Balancer; it received incoming HTTPS traffic on port 443 and forwards it to the target HTTPS proxy.
resource "google_compute_global_forwarding_rule" "web_https_forwarding_rule" {
  name                  = "https-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.web_https_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
}

