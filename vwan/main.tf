# ═══════════════════════════════════════════════════════════════════════════════
# VIRTUAL WAN — Core
# ═══════════════════════════════════════════════════════════════════════════════

resource "azurerm_virtual_wan" "vwan" {
  name                              = var.name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  type                              = var.type
  disable_vpn_encryption            = var.disable_vpn_encryption
  allow_branch_to_branch_traffic    = var.allow_branch_to_branch_traffic
  office365_local_breakout_category = var.office365_local_breakout_category

  tags = var.tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# RESOURCE: Management Lock
# ═══════════════════════════════════════════════════════════════════════════════

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_virtual_wan.vwan.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}
