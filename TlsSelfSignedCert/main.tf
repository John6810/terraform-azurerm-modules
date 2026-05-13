###############################################################
# MODULE: TlsSelfSignedCert - Main
###############################################################

###############################################################
# RSA Private Key
###############################################################
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = var.key_size
}

###############################################################
# Self-signed X.509 Certificate
#
# `allowed_uses` covers what an nginx Ingress TLS cert needs:
#   - server_auth      : Extended Key Usage = TLS Web Server Auth
#   - digital_signature: Key Usage = digitalSignature (TLS handshake)
#   - key_encipherment : Key Usage = keyEncipherment (RSA key exchange)
###############################################################
resource "tls_self_signed_cert" "this" {
  private_key_pem = tls_private_key.this.private_key_pem

  subject {
    common_name  = var.common_name
    organization = var.organization
  }

  dns_names    = var.dns_names
  ip_addresses = var.ip_addresses

  validity_period_hours = var.validity_days * 24
  early_renewal_hours   = 0

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

###############################################################
# Key Vault Certificate (import)
#
# Azure Key Vault stores certs in 3 forms simultaneously:
#   - certificate object (the X.509 cert)
#   - secret object      (cert + private key as PEM or PFX, depending
#                         on secret_properties.content_type)
#   - key object         (the underlying RSA key, for cryptographic ops)
#
# The Application Routing addon CSI driver fetches via the SECRET
# endpoint, so we set content_type = "application/x-pem-file" and
# concatenate cert + private key as PEM. The addon then materializes
# the result as a standard Kubernetes TLS Secret in the Ingress's
# namespace, which nginx-controller consumes via `tls.secretName`.
#
# `issuer_parameters.name = "Self"` is the marker for imports. The
# certificate_policy block must be present (Azure requirement) even
# for imports — it dictates what would happen on renewal.
###############################################################
resource "azurerm_key_vault_certificate" "this" {
  name         = var.cert_name
  key_vault_id = var.key_vault_id

  certificate {
    contents = base64encode("${tls_self_signed_cert.this.cert_pem}${tls_private_key.this.private_key_pem}")
  }

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = var.key_size
      key_type   = "RSA"
      reuse_key  = false
    }

    secret_properties {
      content_type = "application/x-pem-file"
    }
  }

  tags = var.tags
}
