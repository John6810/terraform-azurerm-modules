###############################################################
# MODULE: AksStack — Main (wrapper-style orchestrator)
#
# Composes a full AKS workload bundle by wrapping the canonical
# child modules via git:: source URLs. Single source of truth for
# each child resource — fixes to KeyVault, ManagedIdentity, Aks,
# etc. propagate to AksStack at the next ref bump.
#
# Trade-off vs. inline-style stacks (KeyVaultStack/NetworkStack):
# +10s init time per fresh cache (network fetch of 5 sub-modules)
# in exchange for zero drift and ~250 lines instead of ~700.
###############################################################

resource "time_static" "time" {}

data "azurerm_client_config" "current" {}

###############################################################
# Naming
###############################################################
locals {
  prefix = "${var.subscription_acronym}-${var.environment}-${var.region_code}"

  # KV name reused throughout (24-char limit policed by KeyVault module)
  kv_name_base = "kv-${local.prefix}-${var.kv_workload}"
  kv_name      = var.kv_suffix != null ? "${local.kv_name_base}-${var.kv_suffix}" : local.kv_name_base

  effective_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# OPTIONAL: Resource Group (when create_resource_group = true)
#
# Uses canonical ResourceGroup module — single source of truth.
###############################################################
module "rg" {
  count = var.create_resource_group ? 1 : 0

  source = "git::https://github.com/John6810/terraform-azurerm-modules.git//ResourceGroup?ref=main"

  subscription_acronym = var.subscription_acronym
  environment          = var.environment
  region_code          = var.region_code
  workload             = var.resource_group_workload
  location             = var.location

  tags = local.effective_tags
}

# When create_resource_group = false, look up the existing RG
data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  effective_rg_name = var.create_resource_group ? module.rg[0].name : var.resource_group_name
  effective_rg_id   = var.create_resource_group ? module.rg[0].id : data.azurerm_resource_group.existing[0].id
}

###############################################################
# Control Plane User Assigned Identity
###############################################################
module "id_cp" {
  source = "git::https://github.com/John6810/terraform-azurerm-modules.git//ManagedIdentity?ref=main"

  subscription_acronym = var.subscription_acronym
  environment          = var.environment
  region_code          = var.region_code
  workload             = "aks-cp"
  location             = var.location
  resource_group_name  = local.effective_rg_name

  tags = local.effective_tags
}

###############################################################
# Kubelet User Assigned Identity
###############################################################
module "id_kubelet" {
  source = "git::https://github.com/John6810/terraform-azurerm-modules.git//ManagedIdentity?ref=main"

  subscription_acronym = var.subscription_acronym
  environment          = var.environment
  region_code          = var.region_code
  workload             = "aks-kubelet"
  location             = var.location
  resource_group_name  = local.effective_rg_name

  tags = local.effective_tags
}

###############################################################
# Key Vault — etcd CMK + workload secrets
#
# Premium SKU (HSM-backed keys), RBAC-only, public access disabled.
# `assign_rbac_to_current_user = true` adds the deployer SP for the
# initial key creation; `role_assignments` adds caller-provided
# admins (typically a PIM/RBAC group per the entra-id-rbac convention).
###############################################################
module "kv" {
  source = "git::https://github.com/John6810/terraform-azurerm-modules.git//KeyVault?ref=main"

  subscription_acronym = var.subscription_acronym
  environment          = var.environment
  region_code          = var.region_code
  workload             = var.kv_workload
  # KV name follows the canonical {prefix}-{workload}; kv_suffix is
  # not exposed by KeyVault module — caller must shorten workload
  # if the computed name exceeds 24 chars.
  location            = var.location
  resource_group_name = local.effective_rg_name
  tenant_id           = var.tenant_id

  sku_name                      = var.kv_sku_name
  enable_rbac                   = true
  assign_rbac_to_current_user   = true
  enabled_for_disk_encryption   = true
  soft_delete_retention_days    = var.kv_soft_delete_retention_days
  purge_protection_enabled      = true
  public_network_access_enabled = false

  role_assignments = {
    for idx, pid in var.kv_admin_principal_ids : "admin-${idx}" => {
      role_definition_id_or_name = "Key Vault Administrator"
      principal_id               = pid
    }
  }

  tags = local.effective_tags
}

###############################################################
# Key Vault Key — etcd CMK (KMS v2)
#
# RSA 2048, full key_opts for KMS, automatic rotation.
# depends_on the KV module to wait for the deployer's KV Admin
# role assignment to propagate before the key creation API call.
###############################################################
module "etcd_key" {
  source = "git::https://github.com/John6810/terraform-azurerm-modules.git//KeyVault-Key?ref=main"

  keys = {
    etcd = {
      name         = "aks-etcd-key"
      key_vault_id = module.kv.id
      key_type     = "RSA"
      key_size     = 2048
      key_opts     = ["encrypt", "decrypt", "wrapKey", "unwrapKey"]

      rotation_policy = {
        expire_after         = var.etcd_key_rotation_policy.expire_after
        notify_before_expiry = var.etcd_key_rotation_policy.notify_before_expiry
        automatic = {
          time_after_creation = var.etcd_key_rotation_policy.automatic.time_after_creation
          time_before_expiry  = var.etcd_key_rotation_policy.automatic.time_before_expiry
        }
      }

      tags = local.effective_tags
    }
  }

  depends_on = [
    module.kv,
  ]
}

###############################################################
# AKS Cluster
#
# All Microsoft AKS best-practice defaults baked in by the Aks
# module. AksStack just routes inputs.
###############################################################
module "aks" {
  source = "git::https://github.com/John6810/terraform-azurerm-modules.git//Aks?ref=main"

  subscription_acronym     = var.subscription_acronym
  environment              = var.environment
  region_code              = var.region_code
  workload                 = var.workload
  location                 = var.location
  resource_group_name      = local.effective_rg_name
  node_resource_group_name = var.node_resource_group_name

  tenant_id = var.tenant_id

  # Identities (from this stack's UAMIs)
  cluster_identity_id        = module.id_cp.id
  kubelet_identity_id        = module.id_kubelet.id
  kubelet_identity_client_id = module.id_kubelet.client_id
  kubelet_identity_object_id = module.id_kubelet.principal_id

  # Network
  node_subnet_id       = var.node_subnet_id
  api_server_subnet_id = var.api_server_subnet_id

  # Cluster config
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.sku_tier
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel
  private_dns_zone_id       = var.private_dns_zone_id

  # KMS v2 — gated by kms_v2_enabled.
  # - false (default): cluster deploys without KMS, etcd CMK still created
  #   for later activation via `az aks update`.
  # - true + api_server_subnet_id == null: inline KMS block fires (Aks
  #   module gate), requires KV Private reachability (PE on KV).
  # - true + api_server_subnet_id != null: inline block stays empty, KMS
  #   must be activated post-deploy via `az aks update`.
  kms_key_id       = var.kms_v2_enabled ? module.etcd_key.versionless_ids["etcd"] : null
  kms_key_vault_id = var.kms_v2_enabled ? module.kv.id : null

  # Network profile (CNI Overlay defaults)
  network_policy = var.network_policy
  pod_cidr       = var.pod_cidr
  service_cidr   = var.service_cidr
  dns_service_ip = var.dns_service_ip
  outbound_type  = var.outbound_type

  # System pool
  system_pool_vm_size                      = var.system_pool_vm_size
  system_pool_node_count                   = var.system_pool_node_count
  system_pool_auto_scaling                 = var.system_pool_auto_scaling
  system_pool_min_count                    = var.system_pool_min_count
  system_pool_max_count                    = var.system_pool_max_count
  system_pool_os_disk_type                 = var.system_pool_os_disk_type
  system_pool_os_disk_size_gb              = var.system_pool_os_disk_size_gb
  system_pool_host_encryption_enabled      = var.system_pool_host_encryption_enabled
  system_pool_only_critical_addons_enabled = var.system_pool_only_critical_addons_enabled
  availability_zones                       = var.availability_zones
  upgrade_max_surge                        = var.upgrade_max_surge

  # User node pools
  user_node_pools = var.user_node_pools

  # Cluster features
  vertical_pod_autoscaler_enabled = var.vertical_pod_autoscaler_enabled
  keda_enabled                    = var.keda_enabled
  image_cleaner_enabled           = var.image_cleaner_enabled
  image_cleaner_interval_hours    = var.image_cleaner_interval_hours

  # Maintenance
  maintenance_window = var.maintenance_window

  # Monitoring
  # Note: Container Insights (oms_agent addon) is delegated to ALZ DINE
  # policy in the LZ — the Aks module does not expose an
  # enable_container_insights toggle. var.enable_container_insights on
  # AksStack is reserved for future use if/when ALZ delegation changes.
  log_analytics_workspace_id = var.log_analytics_workspace_id

  tags = local.effective_tags

  depends_on = [
    azurerm_role_assignment.cp_subnet_network_contrib,
  ]
}

###############################################################
# Diagnostic Settings — emitted to centralised LAW.
#
# Inline (not via DiagnosticSettings module) because we already
# wrap 5 modules and adding a 6th git fetch for 1 azurerm resource
# isn't worth the ~10s init latency.
###############################################################
resource "azurerm_monitor_diagnostic_setting" "this" {
  count                      = var.log_analytics_workspace_id != null ? 1 : 0
  name                       = "diag-${module.aks.name}"
  target_resource_id         = module.aks.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "cluster-autoscaler" }
  enabled_log { category = "guard" }

  enabled_metric { category = "AllMetrics" }
}
