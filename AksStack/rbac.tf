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
# RBAC #1b: CP UAMI → Managed Identity Operator on kubelet UAMI
#
# Required when control-plane and kubelet identities are separate
# UAMIs (our pattern). The control plane needs this role to assign
# the kubelet UAMI to VMSS instances at scale-out / upgrade time.
#
# Without this, AKS create fails with:
#   CustomKubeletIdentityMissingPermissionError
###############################################################
resource "azurerm_role_assignment" "cp_kubelet_mi_operator" {
  scope                = module.id_kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = module.id_cp.principal_id
  principal_type       = "ServicePrincipal"
}

###############################################################
# RBAC #1c: CP UAMI → Key Vault Contributor on the etcd KV
#
# Required when KMS Private is enabled. AKS creates an AKS-managed
# Private Endpoint in the AKS-managed node RG that connects to the
# KV's private link service. The CP UAMI initiates this connection
# and needs Microsoft.KeyVault/vaults/PrivateEndpointConnectionsApproval/action
# on the KV to approve the PE connection from the AKS side.
#
# Without this, az aks update --enable-azure-keyvault-kms fails with:
#   LinkedAuthorizationFailed: ... PrivateEndpointConnectionsApproval/action
# and the cluster lands in provisioningState=Failed even though the
# KMS config is partially applied.
#
# Built-in role chosen: "Key Vault Contributor" (includes the action;
# scoped to the KV resource only — minimal blast radius). A custom role
# with just PrivateEndpointConnectionsApproval/action would be tighter
# but adds management overhead — refactor opportunity for Sprint 9.
###############################################################
resource "azurerm_role_assignment" "cp_kv_contributor" {
  count = var.kms_v2_enabled ? 1 : 0

  scope                = module.kv.id
  role_definition_name = "Key Vault Contributor"
  principal_id         = module.id_cp.principal_id
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
# RBAC #2b: CP UAMI → Network Contributor on apiserver subnet
#
# When VNet integration is enabled (kv_pe_subnet_id implies it via the
# Aks module's post-create az aks update), AKS injects the apiserver
# NICs into the apiserver subnet. The CP UAMI needs the
# Microsoft.Network/virtualNetworks/subnets/joinLoadBalancer/action perm,
# which Network Contributor grants.
#
# Without this, az aks update --enable-apiserver-vnet-integration fails
# with ResourceMissingPermissionError on joinLoadBalancer/action.
###############################################################
resource "azurerm_role_assignment" "cp_apiserver_subnet_network_contrib" {
  count = var.api_server_subnet_id != null ? 1 : 0

  scope                = var.api_server_subnet_id
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
