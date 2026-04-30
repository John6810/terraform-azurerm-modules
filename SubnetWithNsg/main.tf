###############################################################
# MODULE: SubnetWithNsg - Main
# Description: Creates subnets with NSG in a single Azure API call
#
# Uses azapi_resource instead of azurerm_subnet because Azure
# Policy "Subnets must have a Network Security Group" (Deny)
# blocks the standard two-step approach (create subnet, then
# associate NSG).
###############################################################

locals {
  # Merge legacy single `delegation` (deprecated) with new `delegations` list.
  # Each subnet ends up with a single concatenated, deduped delegation list.
  effective_subnets = {
    for s in var.subnets : s.name => merge(s, {
      effective_delegations = concat(
        s.delegation != null ? [s.delegation] : [],
        s.delegations,
      )
    })
  }
}

resource "azapi_resource" "subnet" {
  for_each = local.effective_subnets

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
      natGateway = each.value.nat_gateway_id != null ? {
        id = each.value.nat_gateway_id
      } : null
      serviceEndpoints = [
        for svc in each.value.service_endpoints : { service = svc }
      ]
      privateEndpointNetworkPolicies = each.value.private_endpoint_network_policies
      defaultOutboundAccess          = each.value.default_outbound_access_enabled
      delegations = [
        for d in each.value.effective_delegations : {
          name = d.name
          properties = {
            serviceName = d.service_name
          }
        }
      ]
    }
  }
}
