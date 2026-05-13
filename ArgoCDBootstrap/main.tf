###############################################################
# MODULE: ArgoCDBootstrap - Main
###############################################################

###############################################################
# Argo CD repository Secret
#
# Argo CD discovers repository connections by scanning Secrets in
# its namespace with the label
# `argocd.argoproj.io/secret-type: repository`. The secret carries
# the connection params (type, url, username, password/PAT).
###############################################################
resource "kubernetes_secret_v1" "repo" {
  metadata {
    name      = var.repo_secret_name
    namespace = var.argocd_namespace

    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = var.repo_url
    username = var.repo_username
    password = var.repo_pat
  }
}

###############################################################
# Argo CD Application CRD
#
# Declared as a kubernetes_manifest so we don't depend on the
# argocd Terraform provider. CRDs must exist in the cluster
# BEFORE plan (the Argo CD addon installed them).
###############################################################
resource "kubernetes_manifest" "application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = var.application_name
      namespace = var.argocd_namespace
    }

    spec = {
      project = "default"

      source = {
        repoURL        = var.repo_url
        targetRevision = var.application_target_revision
        path           = var.application_path

        directory = {
          recurse = var.directory_recurse
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_namespace
      }

      syncPolicy = {
        automated = {
          prune    = var.sync_policy_prune
          selfHeal = var.sync_policy_self_heal
        }

        syncOptions = [
          "CreateNamespace=true",
        ]
      }
    }
  }

  depends_on = [
    kubernetes_secret_v1.repo,
  ]
}
