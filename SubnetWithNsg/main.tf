###############################################################
# MODULE: SubnetWithNsg - Main
# Description: Creates subnets with NSG in a single Azure API call
#
# Uses azapi_resource instead of azurerm_subnet because Azure
# Policy "Subnets must have a Network Security Group" (Deny)
# blocks the standard two-step approach (create subnet, then
# associate NSG).
###############################################################

resource "azapi_resource" "subnet" {
  for_each = { for s in var.subnets : s.name => s }

  type      = "Microsoft.Network/virtualNetworks/subnets@2025-03-01"
  name      = each.value.name
  parent_id = var.virtual_network_id

  body = {
    properties = {
      addressPrefix = each.value.address_prefix
      networkSecurityGroup = each.value.nsg_id != null ? {
        id = each.value.nsg_id
      } : null
      routeTable = each.value.route_table_id != null ? {
        id = each.value.route_table_id
      } : null
      defaultOutboundAccess = each.value.default_outbound_access_enabled
      delegations = each.value.delegation != null ? [
        {
          name = each.value.delegation.name
          properties = {
            serviceName = each.value.delegation.service_name
          }
        }
      ] : []
    }
  }
}
