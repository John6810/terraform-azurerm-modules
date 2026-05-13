###############################################################
# MODULE: KubernetesClusterExtension - Main
#
# One ARM-managed extension on the target AKS cluster.
# Prerequisite resource providers (the caller must register if
# not already done at sub level):
#   - Microsoft.KubernetesConfiguration
#   - Microsoft.Kubernetes
#   - Microsoft.ContainerService
###############################################################

resource "azurerm_kubernetes_cluster_extension" "this" {
  name           = var.name
  cluster_id     = var.cluster_id
  extension_type = var.extension_type

  release_namespace = var.release_namespace
  target_namespace  = var.target_namespace

  release_train = var.release_train
  version       = var.version

  configuration_settings           = var.configuration_settings
  configuration_protected_settings = var.configuration_protected_settings

  dynamic "plan" {
    for_each = var.plan != null ? [var.plan] : []
    content {
      name           = plan.value.name
      product        = plan.value.product
      publisher      = plan.value.publisher
      promotion_code = plan.value.promotion_code
      version        = plan.value.version
    }
  }
}
