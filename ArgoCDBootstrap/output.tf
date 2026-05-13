###############################################################
# MODULE: ArgoCDBootstrap - Outputs
###############################################################

output "repo_secret_name" {
  description = "Name of the Kubernetes Secret holding the repo credentials."
  value       = kubernetes_secret_v1.repo.metadata[0].name
}

output "application_name" {
  description = "Name of the Argo CD Application CRD."
  value       = var.application_name
}

output "application_repo_url" {
  description = "Repo URL the Application watches."
  value       = var.repo_url
}

output "application_path" {
  description = "Path inside the repo that the Application reconciles."
  value       = var.application_path
}
