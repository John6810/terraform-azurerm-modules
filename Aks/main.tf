###############################################################
# MODULE: Aks - Main
# Description: Azure Kubernetes Service - Private Cluster
#              Azure CNI Overlay, KMS v2, Defender, OIDC/WI
###############################################################

data "azurerm_client_config" "current" {}

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: aks-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    aks-api-prod-gwc-apim
###############################################################
locals {
  computed_name = "aks-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
  node_rg_name  = var.node_resource_group_name != null ? var.node_resource_group_name : "rg-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}-nodes"
  dns_prefix    = var.dns_prefix != null ? var.dns_prefix : replace(local.name, "-", "")
}

###############################################################
# RESOURCE: AKS Cluster
###############################################################
resource "azurerm_kubernetes_cluster" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = local.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  node_resource_group = local.node_rg_name

  # ─── Private Cluster ─────────────────────────────────────────
  private_cluster_enabled = true
  private_dns_zone_id     = var.private_dns_zone_id
  # Public FQDN resolution: explicit override > auto-compute from DNS zone
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled != null ? var.private_cluster_public_fqdn_enabled : (var.private_dns_zone_id == "None")

  # ─── Identity (UserAssigned) ─────────────────────────────────
  identity {
    type         = "UserAssigned"
    identity_ids = [var.cluster_identity_id]
  }

  kubelet_identity {
    client_id                 = var.kubelet_identity_client_id
    object_id                 = var.kubelet_identity_object_id
    user_assigned_identity_id = var.kubelet_identity_id
  }

  # ─── Network Profile - Azure CNI Overlay ─────────────────────
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = var.network_policy
    network_data_plane  = var.network_data_plane
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    outbound_type       = var.outbound_type
  }

  # ─── Default Node Pool (System) ─────────────────────────────
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool_vm_size
    node_count                   = var.system_pool_auto_scaling ? null : var.system_pool_node_count
    min_count                    = var.system_pool_auto_scaling ? var.system_pool_min_count : null
    max_count                    = var.system_pool_auto_scaling ? var.system_pool_max_count : null
    auto_scaling_enabled         = var.system_pool_auto_scaling
    os_disk_type                 = var.system_pool_os_disk_type
    os_disk_size_gb              = var.system_pool_os_disk_size_gb
    host_encryption_enabled      = var.system_pool_host_encryption_enabled
    vnet_subnet_id               = var.node_subnet_id
    zones                        = var.availability_zones
    only_critical_addons_enabled = var.system_pool_only_critical_addons_enabled
    temporary_name_for_rotation  = "tmpsys"

    upgrade_settings {
      max_surge = var.upgrade_max_surge
    }
  }

  # ─── KMS v2 - Azure Key Vault Encryption ────────────────────
  # When api_server_subnet_id is set, KMS is managed via azapi (see below)
  dynamic "key_management_service" {
    for_each = var.kms_key_id != null && var.api_server_subnet_id == null ? [1] : []
    content {
      key_vault_key_id         = var.kms_key_id
      key_vault_network_access = "Private"
    }
  }

  # ─── Azure AD RBAC ──────────────────────────────────────────
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  # ─── OIDC + Workload Identity ──────────────────────────────
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # ─── Microsoft Defender ────────────────────────────────────
  dynamic "microsoft_defender" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  # ─── Managed Prometheus (ama-metrics agent) ───────────────
  monitor_metrics {}

  # ─── Workload Autoscaler Profile (VPA + KEDA) ──────────────
  # Enables the VPA addon (recommender, updater, admission-controller).
  # Per-workload mode (Off/Initial/Auto) configured via VerticalPodAutoscaler
  # CRDs in Kubernetes — NOT at cluster level. Default usage: create VPA
  # objects with updateMode=Off for recommend-only, safe dry-run.
  workload_autoscaler_profile {
    vertical_pod_autoscaler_enabled = var.vertical_pod_autoscaler_enabled
    keda_enabled                    = var.keda_enabled
  }

  # ─── Azure Policy Add-on ──────────────────────────────────
  azure_policy_enabled = true

  # ─── Auto Upgrade ─────────────────────────────────────────
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  # ─── Image Cleaner ──────────────────────────────────────
  image_cleaner_enabled        = var.image_cleaner_enabled
  image_cleaner_interval_hours = var.image_cleaner_enabled ? var.image_cleaner_interval_hours : null

  # ─── Maintenance Window ─────────────────────────────────
  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? [var.maintenance_window] : []
    content {
      allowed {
        day   = maintenance_window.value.day
        hours = range(maintenance_window.value.hour_start, maintenance_window.value.hour_end)
      }
    }
  }

  # ─── Tags ──────────────────────────────────────────────────
  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].node_count,
      # api_server_access_profile and key_management_service are managed
      # outside Terraform via az aks update (azurerm v4 limitation)
      api_server_access_profile,
      key_management_service,
      # ALZ policies deploy oms_agent and modify microsoft_defender casing
      microsoft_defender,
      oms_agent,
    ]
  }
}

###############################################################
# RESOURCE: User Node Pools
###############################################################
resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = var.user_node_pools

  name                        = each.value.name
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.this.id
  vm_size                     = each.value.vm_size
  os_disk_type                = each.value.os_disk_type
  os_disk_size_gb             = each.value.os_disk_size_gb
  host_encryption_enabled     = each.value.host_encryption_enabled
  vnet_subnet_id              = var.node_subnet_id
  zones                       = coalesce(each.value.zones, var.availability_zones)
  auto_scaling_enabled        = each.value.enable_auto_scaling
  min_count                   = each.value.enable_auto_scaling ? each.value.min_count : null
  max_count                   = each.value.enable_auto_scaling ? each.value.max_count : null
  node_count                  = each.value.enable_auto_scaling ? null : coalesce(each.value.node_count, each.value.min_count)
  node_labels                 = each.value.labels
  node_taints                 = each.value.taints
  temporary_name_for_rotation = coalesce(each.value.temporary_name_for_rotation, "${substr(each.value.name, 0, 9)}tmp")

  # Spot pool support — Regular by default, Spot opts in via priority="Spot".
  # Azure auto-applies the kubernetes.azure.com/scalesetpriority=spot:NoSchedule
  # taint to spot pools, but workload-specific tolerations are still required.
  priority        = each.value.priority
  eviction_policy = each.value.priority == "Spot" ? each.value.eviction_policy : null
  spot_max_price  = each.value.priority == "Spot" ? each.value.spot_max_price : null

  upgrade_settings {
    max_surge = var.upgrade_max_surge
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
      NodePool  = each.value.name
    }
  )

  lifecycle {
    ignore_changes = [
      node_count,
    ]
  }
}

###############################################################
# Container Insights — managed by ALZ DINE Policy
# The policy automatically creates a DCR (MSCI-{region}-{cluster})
# and the ContainerInsightsExtension association on each AKS cluster.
# Do not manage here to avoid Terraform vs Policy conflicts.
###############################################################

###############################################################
# RESOURCE: Diagnostic Settings
###############################################################
resource "azurerm_monitor_diagnostic_setting" "this" {
  count                      = var.log_analytics_workspace_id != null ? 1 : 0
  name                       = "diag-${local.name}"
  target_resource_id         = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "cluster-autoscaler" }
  enabled_log { category = "guard" }
}

###############################################################
# RESOURCE: Post-create — VNet Integration + KMS Private (via az CLI)
# ─────────────────────────────────────────────────────────────
# azurerm v4 cannot create a cluster with api_server_access_profile
# or KMS Private inline. azapi_update_resource doesn't correctly
# persist apiServerAccessProfile (PUT body merge bug with AKS
# managedClusters): reports success yet Azure shows enableVnetIntegration
# = null afterwards.
#
# Workaround: null_resource + local-exec calling `az aks update`. The
# provisioner authenticates az CLI as the same SPN that Terraform uses
# (via ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID env vars), in
# an isolated AZURE_CONFIG_DIR so it doesn't pollute the user's az login
# session. Cleaned up after each call.
#
# Pre-requisites on the Terraform runner:
#   - PowerShell 7+ (`pwsh`) available on PATH
#   - `az` CLI installed
#   - Terraform authenticated via SPN secret (ARM_CLIENT_ID, ARM_CLIENT_SECRET,
#     ARM_TENANT_ID set in env). This is the standard Azure DevOps pipeline
#     setup; for cert / OIDC / managed identity, the script needs adaptation.
###############################################################
locals {
  # Shared SPN-login + cleanup wrapper. The {AZ_CMD} placeholder is replaced
  # with the actual az command per resource. Single source of truth for the
  # auth dance.
  #
  # Note: $ErrorActionPreference = "Stop" only catches PowerShell errors,
  # NOT native command exit codes. Each `az` invocation is followed by an
  # explicit $LASTEXITCODE check so a failed `az aks update` (e.g.
  # ResourceMissingPermissionError) properly fails the local-exec instead
  # of being silently marked as success.
  spn_az_cmd_template = <<-EOT
    $ErrorActionPreference = "Stop"
    if (-not $env:ARM_CLIENT_ID -or -not $env:ARM_CLIENT_SECRET -or -not $env:ARM_TENANT_ID) {
      throw "ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID must be set so the local-exec authenticates as the same SPN Terraform uses (got: ID=$($env:ARM_CLIENT_ID -ne $null), SECRET=$($env:ARM_CLIENT_SECRET -ne $null), TENANT=$($env:ARM_TENANT_ID -ne $null))."
    }
    $azDir = Join-Path ([System.IO.Path]::GetTempPath()) ("az-tf-" + [System.Guid]::NewGuid().ToString())
    $env:AZURE_CONFIG_DIR = $azDir
    try {
      az login --service-principal --username $env:ARM_CLIENT_ID --password $env:ARM_CLIENT_SECRET --tenant $env:ARM_TENANT_ID --only-show-errors | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "az login failed (exit $LASTEXITCODE)" }
      {AZ_CMD}
      if ($LASTEXITCODE -ne 0) { throw "az aks update failed (exit $LASTEXITCODE)" }
    } finally {
      Remove-Item -Recurse -Force $azDir -ErrorAction SilentlyContinue
    }
  EOT
}

resource "null_resource" "enable_vnet_integration" {
  count = var.api_server_subnet_id != null ? 1 : 0

  triggers = {
    cluster_id = azurerm_kubernetes_cluster.this.id
    subnet_id  = var.api_server_subnet_id
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-Command"]
    command = replace(
      local.spn_az_cmd_template,
      "{AZ_CMD}",
      join(" ", [
        "az aks update",
        "--name ${azurerm_kubernetes_cluster.this.name}",
        "--resource-group ${azurerm_kubernetes_cluster.this.resource_group_name}",
        "--subscription ${data.azurerm_client_config.current.subscription_id}",
        "--enable-apiserver-vnet-integration",
        "--apiserver-subnet-id ${var.api_server_subnet_id}",
        "--yes --only-show-errors",
      ])
    )
  }

  depends_on = [
    azurerm_kubernetes_cluster.this,
    azurerm_kubernetes_cluster_node_pool.this,
  ]
}

# Brief settle window — Azure may still be propagating apiServerAccessProfile
# state when the KMS update fires, even after `az aks update` returns.
resource "time_sleep" "wait_for_vnet_integration" {
  count           = var.api_server_subnet_id != null && var.kms_key_id != null ? 1 : 0
  depends_on      = [null_resource.enable_vnet_integration]
  create_duration = "30s"

  triggers = {
    vnet_integration_id = null_resource.enable_vnet_integration[0].id
  }
}

resource "null_resource" "enable_kms" {
  count = var.kms_key_id != null && var.api_server_subnet_id != null ? 1 : 0

  triggers = {
    cluster_id   = azurerm_kubernetes_cluster.this.id
    key_id       = var.kms_key_id
    key_vault_id = var.kms_key_vault_id
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-Command"]
    command = replace(
      local.spn_az_cmd_template,
      "{AZ_CMD}",
      join(" ", [
        "az aks update",
        "--name ${azurerm_kubernetes_cluster.this.name}",
        "--resource-group ${azurerm_kubernetes_cluster.this.resource_group_name}",
        "--subscription ${data.azurerm_client_config.current.subscription_id}",
        "--enable-azure-keyvault-kms",
        "--azure-keyvault-kms-key-id ${var.kms_key_id}",
        "--azure-keyvault-kms-key-vault-network-access Private",
        "--azure-keyvault-kms-key-vault-resource-id ${var.kms_key_vault_id}",
        "--yes --only-show-errors",
      ])
    )
  }

  depends_on = [
    time_sleep.wait_for_vnet_integration,
  ]
}
