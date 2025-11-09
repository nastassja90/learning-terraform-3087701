variable "policy_name" {
  description = "Name of the Cloud Armor security policy"
  type        = string
  
  validation {
    condition     = length(var.policy_name) > 0 && can(regex("^[a-z0-9-]+$", var.policy_name))
    error_message = "Policy name must be non-empty and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "description" {
  description = "Description of the Cloud Armor security policy"
  type        = string
  default     = "Cloud Armor security policy managed by Terraform"
}

variable "default_rule_action" {
  description = "Default action for requests that don't match any rule (allow or deny)"
  type        = string
  default     = "allow"  # Permetti traffico di default (il firewall gestisce il deny)
  
  validation {
    condition     = contains(["allow", "deny"], var.default_rule_action)
    error_message = "Default rule action must be either 'allow' or 'deny'."
  }
}

variable "enable_layer7_ddos_defense" {
  description = "Enable Adaptive Protection (Layer 7 DDoS defense with ML)"
  type        = bool
  default     = true
}

variable "json_parsing" {
  description = "JSON parsing mode for request body inspection (DISABLED, STANDARD, or STANDARD_WITH_GRAPHQL)"
  type        = string
  default     = "STANDARD"
  
  validation {
    condition     = contains(["DISABLED", "STANDARD", "STANDARD_WITH_GRAPHQL"], var.json_parsing)
    error_message = "JSON parsing must be DISABLED, STANDARD, or STANDARD_WITH_GRAPHQL."
  }
}

variable "log_level" {
  description = "Log level for security policy (NORMAL or VERBOSE)"
  type        = string
  default     = "VERBOSE"  # GDPR/HIPAA: massimo dettaglio per audit
  
  validation {
    condition     = contains(["NORMAL", "VERBOSE"], var.log_level)
    error_message = "Log level must be NORMAL or VERBOSE."
  }
}

# ===============================
# IP Whitelist/Blacklist
# ===============================

variable "ip_whitelist" {
  description = "List of IP ranges to always allow (e.g., corporate offices, monitoring services)"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for cidr in var.ip_whitelist : 
      can(cidrhost(cidr, 0))
    ])
    error_message = "All IP whitelist entries must be valid CIDR blocks."
  }
}

variable "ip_blacklist" {
  description = "List of IP ranges to always block (e.g., known malicious IPs)"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for cidr in var.ip_blacklist : 
      can(cidrhost(cidr, 0))
    ])
    error_message = "All IP blacklist entries must be valid CIDR blocks."
  }
}

variable "geo_whitelist" {
  description = "List of country codes to allow (ISO 3166-1 alpha-2). Empty list means all countries allowed."
  type        = list(string)
  default     = []  # Vuoto = permetti tutti (specificare in produzione per GDPR)
  
  validation {
    condition = alltrue([
      for code in var.geo_whitelist : 
      length(code) == 2 && can(regex("^[A-Z]{2}$", code))
    ])
    error_message = "Country codes must be 2-letter ISO 3166-1 alpha-2 codes (e.g., IT, US, GB)."
  }
}

variable "geo_blacklist" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for code in var.geo_blacklist : 
      length(code) == 2 && can(regex("^[A-Z]{2}$", code))
    ])
    error_message = "Country codes must be 2-letter ISO 3166-1 alpha-2 codes."
  }
}

# ===============================
# Rate Limiting
# ===============================

variable "enable_rate_limiting" {
  description = "Enable rate limiting rules"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Maximum requests per minute per IP before rate limiting kicks in"
  type        = number
  default     = 100
  
  validation {
    condition     = var.rate_limit_threshold > 0 && var.rate_limit_threshold <= 10000
    error_message = "Rate limit threshold must be between 1 and 10000 requests per minute."
  }
}

variable "rate_limit_ban_duration_sec" {
  description = "Duration in seconds to ban an IP that exceeds rate limit"
  type        = number
  default     = 600  # 10 minuti
  
  validation {
    condition     = var.rate_limit_ban_duration_sec >= 60 && var.rate_limit_ban_duration_sec <= 86400
    error_message = "Ban duration must be between 60 seconds (1 min) and 86400 seconds (24 hours)."
  }
}

# ===============================
# OWASP Protection
# ===============================

variable "enable_owasp_rules" {
  description = "Enable OWASP ModSecurity Core Rule Set (CRS) protections"
  type        = bool
  default     = true
}

variable "owasp_rules" {
  description = "OWASP attack types to protect against"
  type = object({
    sqli                = bool  # SQL Injection
    xss                 = bool  # Cross-Site Scripting
    lfi                 = bool  # Local File Inclusion
    rfi                 = bool  # Remote File Inclusion
    rce                 = bool  # Remote Code Execution
    php_injection       = bool  # PHP Code Injection
    session_fixation    = bool  # Session Fixation
    scanner_detection   = bool  # Scanner/Bot Detection
    protocol_attack     = bool  # Protocol Attacks
    method_enforcement  = bool  # HTTP Method Enforcement
  })
  default = {
    sqli                = true
    xss                 = true
    lfi                 = true
    rfi                 = true
    rce                 = true
    php_injection       = true
    session_fixation    = true
    scanner_detection   = true
    protocol_attack     = true
    method_enforcement  = true
  }
}

variable "owasp_sensitivity_level" {
  description = "Sensitivity level for OWASP rules (0-4, where 0=paranoid, 4=tolerant)"
  type        = number
  default     = 1  # Bilanciamento tra sicurezza e false positive
  
  validation {
    condition     = var.owasp_sensitivity_level >= 0 && var.owasp_sensitivity_level <= 4
    error_message = "OWASP sensitivity level must be between 0 (most strict) and 4 (most permissive)."
  }
}

# ===============================
# Custom Rules
# ===============================

variable "custom_rules" {
  description = "List of custom security rules"
  type = list(object({
    priority    = number
    description = string
    action      = string  # "allow", "deny", "rate_based_ban", or "throttle"
    preview     = bool    # Set to true to test rule without enforcing
    expression  = string  # CEL expression for matching
    
    # Rate limiting (solo se action = "rate_based_ban" o "throttle")
    rate_limit_options = optional(object({
      exceed_action                = string  # "deny" or "log"
      rate_limit_threshold_count   = number
      rate_limit_threshold_interval_sec = number
      ban_duration_sec            = number
    }))
    
    # Redirect (solo se action = "redirect")
    redirect_options = optional(object({
      type   = string  # "GOOGLE_RECAPTCHA" or "EXTERNAL_302"
      target = string
    }))
  }))
  default = []
}

# ===============================
# Recaptcha Integration
# ===============================

variable "enable_recaptcha" {
  description = "Enable reCAPTCHA challenge for suspicious traffic"
  type        = bool
  default     = false  # Da abilitare se si ha enterprise recaptcha
}

variable "recaptcha_site_key" {
  description = "reCAPTCHA Enterprise site key"
  type        = string
  default     = ""
  sensitive   = true
}

# ===============================
# Advanced Features
# ===============================

variable "enable_json_custom_content" {
  description = "Enable custom JSON response for blocked requests (GDPR transparency)"
  type        = bool
  default     = true
}

variable "custom_error_response_body" {
  description = "Custom error message for blocked requests (GDPR: informare l'utente)"
  type        = string
  default     = <<-EOT
  {
    "error": {
      "code": 403,
      "message": "Access denied due to security policy",
      "details": "Your request was blocked by our security system. If you believe this is an error, please contact support with reference ID: {request_id}"
    }
  }
  EOT
}

variable "enable_bot_management" {
  description = "Enable advanced bot management (requires Cloud Armor Plus)"
  type        = bool
  default     = false
}