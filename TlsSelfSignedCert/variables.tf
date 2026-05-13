###############################################################
# MODULE: TlsSelfSignedCert - Variables
#
# Generates a self-signed TLS certificate via the `tls` provider
# and imports it into an existing Azure Key Vault as a Certificate
# resource. Suitable for internal/private clusters where browser
# trust isn't needed (the cert chain is rejected by browsers but
# the TLS handshake succeeds and all origin/redirect checks pass).
#
# Use cases:
#   - Argo CD / Grafana / Prometheus UI on a VPN-only AKS cluster
#   - Internal-only nginx Ingress fronted by AKS Application Routing
#
# Pattern:
#   1. tls_private_key + tls_self_signed_cert produce PEM material
#   2. PEM (cert || key) is base64-encoded and imported as an
#      azurerm_key_vault_certificate with issuer_parameters.name = "Self"
#   3. App Routing CSI driver pulls the cert via the standard
#      `kubernetes.azure.com/tls-cert-keyvault-uri` Ingress annotation
#
# The caller is responsible for granting `Key Vault Secrets User`
# to the App Routing UAMI (or any other reader) on the target KV.
###############################################################

variable "cert_name" {
  type        = string
  description = "Name of the certificate inside the Key Vault. Must be unique per KV and match `[a-zA-Z0-9-]{1,127}`."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,127}$", var.cert_name))
    error_message = "cert_name must be 1-127 alphanumeric / hyphen characters."
  }
}

variable "key_vault_id" {
  type        = string
  description = "Resource ID of the Key Vault that will host the certificate."
  nullable    = false
}

variable "common_name" {
  type        = string
  description = "Subject CN of the certificate (e.g. `*.shc.az.epttst.lu`). Goes into the cert's distinguished name. Wildcard CN is accepted but modern browsers/clients rely on Subject Alternative Names — always populate `dns_names` as well."
  nullable    = false
}

variable "organization" {
  type        = string
  description = "Subject O field. Cosmetic — shown in cert viewers."
  default     = "Post Luxembourg"
}

variable "dns_names" {
  type        = list(string)
  description = "Subject Alternative Names (DNS). Modern TLS clients verify the SAN list, not the CN. Include the wildcard and any specific hostnames the cert should be valid for. Example: [\"*.shc.az.epttst.lu\", \"shc.az.epttst.lu\"]."
  default     = []
}

variable "ip_addresses" {
  type        = list(string)
  description = "Subject Alternative Names (IP). Rarely needed for ingress certs."
  default     = []
}

variable "validity_days" {
  type        = number
  description = "Cert validity in days. Default 1825 (5 years) — long enough to skip rotation for non-prod self-signed certs. The `tls` provider auto-renews when `now() >= validity_start + validity_period - early_renewal`; we leave early_renewal_hours = 0 so the cert is replaced only after expiry."
  default     = 1825

  validation {
    condition     = var.validity_days > 0 && var.validity_days <= 3650
    error_message = "validity_days must be between 1 and 3650 (10 years)."
  }
}

variable "key_size" {
  type        = number
  description = "RSA key size in bits."
  default     = 2048

  validation {
    condition     = contains([2048, 3072, 4096], var.key_size)
    error_message = "key_size must be 2048, 3072, or 4096."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the Key Vault certificate object."
  default     = {}
}
