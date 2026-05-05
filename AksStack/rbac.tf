###############################################################
# MODULE: AksStack — RBAC role assignments
#
# 4 RBAC patterns, kept inline (not via RbacAssignments module —
# AksStack already wraps 5 modules; one more git fetch for 4
# trivial role_assignment resources is over-engineering).
#
#   1. Kubelet UAMI → Key Vault Crypto User on the etcd KV.
#   2. CP UAMI → Network Contributor on the node subnet (required
#      before AKS create — depends_on guard in main.tf).
#   3. Kubelet UAMI → AcrPull on each ACR in var.acr_pull_target_ids.
#   4. Optional caller-provided cluster admin / user role grants
#      (Azure RBAC for Kubernetes API).
###############################################################

###############################################################
# RBAC #1: Kubelet UAMI → Key Vault Crypto User (for etcd CMK)
###############################################################
resource "azurerm_role_assignment" "kubelet_kv_crypto_user" {
  scope                = module.kv.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = module.id_kubelet.principal_id
  principal_type       = "ServicePrincipal"
}

###############################################################
# RBAC #2: CP UAMI → Network Contributor on node subnet
#
# Required so AKS can create the load balancer NICs, attach the
# node NICs to the subnet, and manage subnet-level config on
# behalf of the cluster.
###############################################################
resource "azurerm_role_assignment" "cp_subnet_network_contrib" {
  scope                = var.node_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = module.id_cp.principal_id
  principal_type       = "ServicePrincipal"
}

###############################################################
# RBAC #3: Kubelet UAMI → AcrPull on each ACR
###############################################################
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  for_each = toset(var.acr_pull_target_ids)

  scope                = each.value
  role_definition_name = "AcrPull"
  principal_id         = module.id_kubelet.principal_id
  principal_type       = "ServicePrincipal"
}

###############################################################
# RBAC #4a: Cluster Admin (caller-provided)
###############################################################
resource "azurerm_role_assignment" "cluster_admin" {
  for_each = toset(var.cluster_admin_principal_ids)

  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}

###############################################################
# RBAC #4b: Cluster User (caller-provided — kubectl exec/logs)
###############################################################
resource "azurerm_role_assignment" "cluster_user" {
  for_each = toset(var.cluster_user_principal_ids)

  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.value
}
