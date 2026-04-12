###############################################################
# MODULE: ResourceLock - Main
# Description: Creates management locks on Azure resources.
#              Use enable_locks = false to disable during maintenance.
###############################################################

resource "azurerm_management_lock" "this" {
  for_each = var.enable_locks ? var.locks : {}

  name       = each.value.name
  scope      = each.value.scope
  lock_level = each.value.lock_level
  notes      = each.value.notes
}
