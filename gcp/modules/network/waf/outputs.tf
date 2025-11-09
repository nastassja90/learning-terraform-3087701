output "policy_id" {
  description = "ID of the Cloud Armor security policy"
  value       = google_compute_security_policy.policy.id
}

output "policy_name" {
  description = "Name of the Cloud Armor security policy"
  value       = google_compute_security_policy.policy.name
}

output "policy_self_link" {
  description = "Self link of the Cloud Armor security policy (for attaching to backend services)"
  value       = google_compute_security_policy.policy.self_link
}

output "policy_fingerprint" {
  description = "Fingerprint of the security policy (for change tracking)"
  value       = google_compute_security_policy.policy.fingerprint
}

# Outputs per audit e troubleshooting
output "enabled_protections" {
  description = "Summary of enabled security protections"
  value = {
    layer7_ddos           = var.enable_layer7_ddos_defense
    rate_limiting         = var.enable_rate_limiting
    owasp_protection      = var.enable_owasp_rules
    ip_whitelist_count    = length(var.ip_whitelist)
    ip_blacklist_count    = length(var.ip_blacklist)
    geo_whitelist_count   = length(var.geo_whitelist)
    geo_blacklist_count   = length(var.geo_blacklist)
    custom_rules_count    = length(var.custom_rules)
    log_level             = var.log_level
  }
}

output "owasp_rules_enabled" {
  description = "List of enabled OWASP protection rules"
  value = [
    for rule_type, config in var.owasp_rules : rule_type
    if config == true
  ]
}

output "rate_limit_config" {
  description = "Rate limiting configuration summary"
  value = var.enable_rate_limiting ? {
    threshold_per_minute = var.rate_limit_threshold
    ban_duration_seconds = var.rate_limit_ban_duration_sec
  } : null
}

output "geographic_restrictions" {
  description = "Geographic restriction summary"
  value = {
    whitelisted_countries = var.geo_whitelist
    blacklisted_countries = var.geo_blacklist
    mode = length(var.geo_whitelist) > 0 ? "whitelist-only" : (
      length(var.geo_blacklist) > 0 ? "blacklist" : "no-restrictions"
    )
  }
}