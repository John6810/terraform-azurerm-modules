###############################################################
# MODULE: Grafana - Main
# Description: Azure Managed Grafana with identity, RBAC,
#              and Azure Monitor Workspace integration
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
###############################################################
locals {
  base         = "${var.subscription_acronym}-${var.environment}-${var.region_code}"
  rg_name      = "rg-${local.base}-grafana"
  id_name      = "id-${local.base}-grafana"
  grafana_name = "amg-${local.base}-01"

  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"

  common_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Resource Group
###############################################################
resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

###############################################################
# RESOURCE: User Assigned Managed Identity
###############################################################
resource "azurerm_user_assigned_identity" "this" {
  name                = local.id_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

###############################################################
# RESOURCE: Identity Role Assignments
###############################################################
resource "azurerm_role_assignment" "identity" {
  for_each = var.identity_role_assignments

  scope                = each.value.scope
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  principal_type       = "ServicePrincipal"
  role_definition_id   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
}

###############################################################
# RESOURCE: Azure Managed Grafana
###############################################################
resource "azurerm_dashboard_grafana" "this" {
  name                = local.grafana_name
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location

  grafana_major_version             = var.grafana_major_version
  sku                               = var.grafana_sku
  zone_redundancy_enabled           = var.zone_redundancy_enabled
  api_key_enabled                   = var.api_key_enabled
  deterministic_outbound_ip_enabled = var.deterministic_outbound_ip_enabled
  public_network_access_enabled     = var.public_network_access_enabled

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  dynamic "azure_monitor_workspace_integrations" {
    for_each = var.azure_monitor_workspace_ids
    content {
      resource_id = azure_monitor_workspace_integrations.value
    }
  }

  tags = local.common_tags
}

###############################################################
# RESOURCE: Grafana RBAC
###############################################################
resource "azurerm_role_assignment" "grafana_admin" {
  for_each = toset(var.grafana_admin_group_object_ids)

  scope                = azurerm_dashboard_grafana.this.id
  principal_id         = each.value
  principal_type       = "Group"
  role_definition_name = "Grafana Admin"
}

resource "azurerm_role_assignment" "grafana_editor" {
  for_each = toset(var.grafana_editor_group_object_ids)

  scope                = azurerm_dashboard_grafana.this.id
  principal_id         = each.value
  principal_type       = "Group"
  role_definition_name = "Grafana Editor"
}

resource "azurerm_role_assignment" "grafana_viewer" {
  for_each = toset(var.grafana_viewer_group_object_ids)

  scope                = azurerm_dashboard_grafana.this.id
  principal_id         = each.value
  principal_type       = "Group"
  role_definition_name = "Grafana Viewer"
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_dashboard_grafana.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}
