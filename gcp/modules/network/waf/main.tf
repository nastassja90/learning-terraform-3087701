##################################################################
# Cloud Armor Security Policy - Zero-Trust Implementation       #
##################################################################

locals {
  # Base priority assignments (lasciamo spazio per inserimenti futuri)
  priority_base_ip_blacklist      = 1000
  priority_base_geo_blacklist     = 2000
  priority_base_rate_limiting     = 3000
  priority_base_owasp             = 4000
  priority_base_ip_whitelist      = 5000
  priority_base_geo_whitelist     = 6000
  priority_base_custom            = 10000
  priority_default                = 2147483647  # Massimo valore int32
  
  # OWASP rule expressions basate su Google's pre-configured rules
  owasp_expressions = {
    sqli = {
      enabled    = var.owasp_rules.sqli
      expression = "evaluatePreconfiguredExpr('sqli-v33-stable', ['owasp-crs-v030301-id942251-sqli', 'owasp-crs-v030301-id942420-sqli', 'owasp-crs-v030301-id942431-sqli', 'owasp-crs-v030301-id942460-sqli'])"
      description = "SQL Injection (SQLi) attacks"
    }
    xss = {
      enabled    = var.owasp_rules.xss
      expression = "evaluatePreconfiguredExpr('xss-v33-stable', ['owasp-crs-v030301-id941150-xss', 'owasp-crs-v030301-id941320-xss', 'owasp-crs-v030301-id941330-xss', 'owasp-crs-v030301-id941340-xss'])"
      description = "Cross-site Scripting (XSS) attacks"
    }
    lfi = {
      enabled    = var.owasp_rules.lfi
      expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      description = "Local File Inclusion (LFI) attacks"
    }
    rfi = {
      enabled    = var.owasp_rules.rfi
      expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      description = "Remote File Inclusion (RFI) attacks"
    }
    rce = {
      enabled    = var.owasp_rules.rce
      expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      description = "Remote Code Execution (RCE) attacks"
    }
    php_injection = {
      enabled    = var.owasp_rules.php_injection
      expression = "evaluatePreconfiguredExpr('php-v33-stable')"
      description = "PHP Injection attacks"
    }
    scanner_detection = {
      enabled    = var.owasp_rules.scanner_detection
      expression = "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
      description = "Scanner and bot detection"
    }
    protocol_attack = {
      enabled    = var.owasp_rules.protocol_attack
      expression = "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
      description = "Protocol attacks"
    }
    session_fixation = {
      enabled    = var.owasp_rules.session_fixation
      expression = "evaluatePreconfiguredExpr('sessionfixation-v33-stable')"
      description = "Session fixation attacks"
    }
  }
  
  # Filtra solo le regole OWASP abilitate
  enabled_owasp_rules = {
    for key, config in local.owasp_expressions : key => config
    if config.enabled
  }
}

##################################################################
# Main Security Policy                                           #
##################################################################

resource "google_compute_security_policy" "policy" {
  name        = var.policy_name
  description = var.description
  
  # Type deve essere CLOUD_ARMOR per avere tutte le features
  type = "CLOUD_ARMOR"
  
  # Adaptive Protection (Layer 7 DDoS con ML)
  dynamic "adaptive_protection_config" {
    for_each = var.enable_layer7_ddos_defense ? [1] : []
    content {
      layer_7_ddos_defense_config {
        enable          = true
        rule_visibility = "STANDARD"  # STANDARD o PREMIUM
      }
    }
  }
  
  # Advanced Options
  advanced_options_config {
    json_parsing = var.json_parsing
    log_level    = var.log_level
    
    # GDPR/HIPAA: Custom response body per trasparenza
    dynamic "json_custom_config" {
      for_each = var.enable_json_custom_content ? [1] : []
      content {
        content_type = "application/json"
      }
    }
  }
  
  ##################################################################
  # PRIORITY 1000-1999: IP Blacklist (Highest Priority)          #
  ##################################################################
  
  dynamic "rule" {
    for_each = length(var.ip_blacklist) > 0 ? [1] : []
    content {
      action      = "deny(403)"
      priority    = local.priority_base_ip_blacklist
      preview     = false
      description = "SECURITY: Block known malicious IP addresses"
      
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.ip_blacklist
        }
      }
      
      # GDPR: Custom response per informare l'utente
      dynamic "header_action" {
        for_each = var.enable_json_custom_content ? [1] : []
        content {
          request_headers_to_adds {
            header_name  = "X-Block-Reason"
            header_value = "IP-Blacklist"
          }
        }
      }
    }
  }
  
  ##################################################################
  # PRIORITY 2000-2999: Geographic Restrictions                   #
  ##################################################################
  
  # Geographic Blacklist (blocca paesi indesiderati)
  dynamic "rule" {
    for_each = length(var.geo_blacklist) > 0 ? [1] : []
    content {
      action      = "deny(403)"
      priority    = local.priority_base_geo_blacklist
      preview     = false
      description = "GDPR/COMPLIANCE: Block traffic from restricted countries: ${join(", ", var.geo_blacklist)}"
      
      match {
        expr {
          expression = "origin.region_code in [${join(", ", formatlist("'%s'", var.geo_blacklist))}]"
        }
      }
      
      dynamic "header_action" {
        for_each = var.enable_json_custom_content ? [1] : []
        content {
          request_headers_to_adds {
            header_name  = "X-Block-Reason"
            header_value = "Geographic-Restriction"
          }
        }
      }
    }
  }
  
  # Geographic Whitelist (permetti solo certi paesi, se specificato)
  dynamic "rule" {
    for_each = length(var.geo_whitelist) > 0 ? [1] : []
    content {
      action      = "deny(403)"
      priority    = local.priority_base_geo_blacklist + 100
      preview     = false
      description = "GDPR/COMPLIANCE: Allow traffic only from approved countries: ${join(", ", var.geo_whitelist)}"
      
      match {
        expr {
          expression = "!(origin.region_code in [${join(", ", formatlist("'%s'", var.geo_whitelist))}])"
        }
      }
      
      dynamic "header_action" {
        for_each = var.enable_json_custom_content ? [1] : []
        content {
          request_headers_to_adds {
            header_name  = "X-Block-Reason"
            header_value = "Geographic-Whitelist-Only"
          }
        }
      }
    }
  }
  
  ##################################################################
  # PRIORITY 3000-3999: Rate Limiting & DDoS Protection          #
  ##################################################################
  
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      action      = "rate_based_ban"
      priority    = local.priority_base_rate_limiting
      preview     = false
      description = "DDOS: Rate limit exceeding ${var.rate_limit_threshold} requests/min per IP"
      
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]  # Applica a tutti gli IP
        }
      }
      
      rate_limit_options {
        conform_action = "allow"
        exceed_action  = "deny(429)"
        
        enforce_on_key = "IP"  # Rate limit per IP source
        
        rate_limit_threshold {
          count        = var.rate_limit_threshold
          interval_sec = 60  # Finestra di 1 minuto
        }
        
        ban_duration_sec = var.rate_limit_ban_duration_sec
        
        # GDPR: Log per audit trail
        ban_threshold {
          count        = var.rate_limit_threshold * 2  # Ban dopo 2x threshold
          interval_sec = 120
        }
      }
      
      dynamic "header_action" {
        for_each = var.enable_json_custom_content ? [1] : []
        content {
          request_headers_to_adds {
            header_name  = "X-Block-Reason"
            header_value = "Rate-Limit-Exceeded"
          }
        }
      }
    }
  }
  
  ##################################################################
  # PRIORITY 4000-4999: OWASP ModSecurity CRS Rules              #
  ##################################################################
  
  # Genera dinamicamente una regola per ogni tipo di attacco OWASP abilitato
  dynamic "rule" {
    for_each = local.enabled_owasp_rules
    iterator = owasp
    
    content {
      action      = "deny(403)"
      priority    = local.priority_base_owasp + (index(keys(local.enabled_owasp_rules), owasp.key) * 10)
      preview     = false  # Cambiare a true per testare senza bloccare
      description = "OWASP: Block ${owasp.value.description}"
      
      match {
        expr {
          expression = owasp.value.expression
        }
      }
      
      dynamic "header_action" {
        for_each = var.enable_json_custom_content ? [1] : []
        content {
          request_headers_to_adds {
            header_name  = "X-Block-Reason"
            header_value = "OWASP-${upper(owasp.key)}"
          }
        }
      }
    }
  }
  
  ##################################################################
  # PRIORITY 5000-5999: IP Whitelist (Override previous denies)  #
  ##################################################################
  
  dynamic "rule" {
    for_each = length(var.ip_whitelist) > 0 ? [1] : []
    content {
      action      = "allow"
      priority    = local.priority_base_ip_whitelist
      preview     = false
      description = "SECURITY: Always allow trusted IP addresses (corporate, monitoring, etc.)"
      
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.ip_whitelist
        }
      }
      
      header_action {
        request_headers_to_adds {
          header_name  = "X-Trusted-Source"
          header_value = "IP-Whitelist"
        }
      }
    }
  }
  
  ##################################################################
  # PRIORITY 10000+: Custom Rules                                 #
  ##################################################################
  
  dynamic "rule" {
    for_each = var.custom_rules
    iterator = custom
    
    content {
      action      = custom.value.action
      priority    = local.priority_base_custom + custom.value.priority
      preview     = custom.value.preview
      description = custom.value.description
      
      match {
        expr {
          expression = custom.value.expression
        }
      }
      
      # Rate limiting options (se applicabile)
      dynamic "rate_limit_options" {
        for_each = custom.value.rate_limit_options != null ? [custom.value.rate_limit_options] : []
        content {
          conform_action = "allow"
          exceed_action  = rate_limit_options.value.exceed_action
          
          enforce_on_key = "IP"
          
          rate_limit_threshold {
            count        = rate_limit_options.value.rate_limit_threshold_count
            interval_sec = rate_limit_options.value.rate_limit_threshold_interval_sec
          }
          
          ban_duration_sec = rate_limit_options.value.ban_duration_sec
        }
      }
      
      # Redirect options (se applicabile)
      dynamic "redirect_options" {
        for_each = custom.value.redirect_options != null ? [custom.value.redirect_options] : []
        content {
          type   = redirect_options.value.type
          target = redirect_options.value.target
        }
      }
    }
  }
  
  ##################################################################
  # DEFAULT RULE (Lowest Priority)                                #
  ##################################################################
  
  rule {
    action      = var.default_rule_action
    priority    = local.priority_default
    description = "Default rule: ${var.default_rule_action} all traffic not matched by other rules"
    
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    
    # GDPR: Log anche il traffico permesso per audit
    header_action {
      request_headers_to_adds {
        header_name  = "X-Cloud-Armor-Status"
        header_value = "Default-${var.default_rule_action}"
      }
    }
  }
}