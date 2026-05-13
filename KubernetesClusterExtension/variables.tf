###############################################################
# MODULE: KubernetesClusterExtension - Variables
#
# Thin generic wrapper around azurerm_kubernetes_cluster_extension.
# Used to install ARM-managed cluster extensions on AKS clusters:
# Argo CD, Flux, Dapr, Azure App Configuration, etc.
#
# This module does NOT bundle any extension-specific defaults — the
# caller passes `extension_type`, `configuration_settings`, etc. for
# the target extension. Microsoft docs list the per-extension config
# keys (see https://learn.microsoft.com/azure/aks/cluster-extensions).
###############################################################

variable "name" {
  type        = string
  description = "Name of the extension instance on the cluster (e.g. \"argocd\", \"flux\")."
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.name))
    error_message = "name must be 1-63 lowercase letters/digits/hyphens, starting with a letter."
  }
}

variable "cluster_id" {
  type        = string
  description = "Full resource ID of the target AKS cluster."
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ContainerService/managedClusters/[^/]+$", var.cluster_id))
    error_message = "cluster_id must be a valid AKS resource ID."
  }
}

variable "extension_type" {
  type        = string
  description = <<-EOT
  Extension type (case-sensitive). Examples:
    - "Microsoft.ArgoCD"   (Argo CD GitOps, currently Preview)
    - "microsoft.flux"     (Flux v2 GitOps, GA)
    - "Microsoft.Dapr"     (Dapr runtime)
    - "Microsoft.AzureML.Kubernetes"  (Azure Machine Learning)
  See: https://learn.microsoft.com/azure/aks/cluster-extensions
  EOT
  nullable    = false
}

variable "release_namespace" {
  type        = string
  description = "Namespace to install the extension into (cluster-scoped install). Mutually exclusive with target_namespace."
  default     = null
}

variable "target_namespace" {
  type        = string
  description = "Single namespace to scope the extension to (namespace-scoped install). Mutually exclusive with release_namespace."
  default     = null
}

variable "release_train" {
  type        = string
  description = "Release train: \"Stable\" (default), \"Preview\", or other extension-specific train (e.g. ArgoCD currently uses Preview)."
  default     = null
}

variable "version" {
  type        = string
  description = "Pin a specific extension version (e.g. \"1.0.0-preview\"). Mutually exclusive with release_train."
  default     = null
}

variable "configuration_settings" {
  type        = map(string)
  description = "Public configuration settings forwarded to the extension. Keys vary per extension (see MS docs)."
  default     = {}
}

variable "configuration_protected_settings" {
  type        = map(string)
  description = "Sensitive configuration settings (SSH keys, OAuth secrets, etc.). Stored encrypted by Azure."
  default     = {}
  sensitive   = true
}

variable "plan" {
  type = object({
    name           = string
    product        = string
    publisher      = string
    promotion_code = optional(string)
    version        = optional(string)
  })
  description = "Marketplace plan, if the extension is a paid Kubernetes app (typically null for first-party Microsoft extensions like Argo CD/Flux)."
  default     = null
}
