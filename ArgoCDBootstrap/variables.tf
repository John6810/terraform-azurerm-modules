###############################################################
# MODULE: ArgoCDBootstrap - Variables
#
# Deploys 2 Kubernetes resources in the `argocd` namespace of an
# AKS cluster:
#
#   1. A Kubernetes Secret holding the Git repo credentials
#      (PAT for Azure DevOps / GitHub / etc.). The secret carries
#      the label `argocd.argoproj.io/secret-type: repository` so
#      Argo CD picks it up as a repository connection.
#
#   2. An Argo CD `Application` CRD (apiVersion
#      argoproj.io/v1alpha1) that points at the same repo and a
#      path. Sync policy = automated + prune + selfHeal so manual
#      drift is automatically corrected.
#
# Provider note: this module REQUIRES a kubernetes provider to be
# configured in the caller (Terragrunt typically generates one
# from `data.azurerm_kubernetes_cluster.this.kube_admin_config`).
# The module itself does not pin the cluster — the provider does.
###############################################################

variable "repo_url" {
  type        = string
  description = "Full HTTPS URL of the Git repository Argo CD will pull (e.g. https://dev.azure.com/<org>/<project>/_git/<repo>)."
  nullable    = false
}

variable "repo_pat" {
  type        = string
  description = "Personal Access Token (or password) used to authenticate Argo CD to the Git repository. Must have Code: Read scope on the target repo."
  sensitive   = true
  nullable    = false
}

variable "repo_username" {
  type        = string
  description = "Username paired with the PAT. For Azure DevOps PATs the value is ignored by the server but must be non-empty (any string works)."
  default     = "argocd"
}

variable "repo_secret_name" {
  type        = string
  description = "Name of the Kubernetes Secret holding the repo credentials. Must be unique within the `argocd` namespace."
  default     = "argocd-platform-manifests-repo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.repo_secret_name))
    error_message = "repo_secret_name must be 1-63 lowercase letters/digits/hyphens, starting with a letter."
  }
}

variable "application_name" {
  type        = string
  description = "Name of the Argo CD Application CRD."
  default     = "platform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.application_name))
    error_message = "application_name must be 1-63 lowercase letters/digits/hyphens, starting with a letter."
  }
}

variable "application_path" {
  type        = string
  description = "Path inside the Git repository that Argo CD reconciles. Typically `platform/` for the bootstrap manifest set."
  default     = "platform"
}

variable "application_target_revision" {
  type        = string
  description = "Git revision (branch, tag, commit SHA) that Argo CD watches. HEAD = always reconcile from the default branch tip."
  default     = "HEAD"
}

variable "destination_namespace" {
  type        = string
  description = "Default destination namespace for manifests in the Application path that omit their own namespace metadata. Per-resource `metadata.namespace` overrides this."
  default     = "argocd"
}

variable "sync_policy_prune" {
  type        = bool
  description = "Delete resources from the cluster when they are removed from the Git repo."
  default     = true
}

variable "sync_policy_self_heal" {
  type        = bool
  description = "Revert manual drift on the cluster back to the Git-declared state."
  default     = true
}

variable "directory_recurse" {
  type        = bool
  description = "When true, Argo CD discovers manifests recursively under `application_path`. Required if you organise manifests in subdirectories (e.g. platform/ingresses/, platform/network-policies/, ...). Default true — platform/ usually has subfolders."
  default     = true
}

variable "argocd_namespace" {
  type        = string
  description = "Namespace where Argo CD is installed (where the repo secret and Application CRD are created)."
  default     = "argocd"
}
