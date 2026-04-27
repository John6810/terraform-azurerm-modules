###############################################################
# MODULE: ResourceGroupSet - Outputs
###############################################################

output "resource_groups" {
  description = "Map of created resource groups keyed by the input map key. Each value: { id, name, location, tags }."
  value = {
    for k, rg in azurerm_resource_group.this :
    k => {
      id       = rg.id
      name     = rg.name
      location = rg.location
      tags     = rg.tags
    }
  }
}

output "ids" {
  description = "Map of resource group IDs keyed by the input map key. Convenience for `dependency.rg.outputs.ids[\"network\"]`."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.id }
}

output "names" {
  description = "Map of resource group names keyed by the input map key."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.name }
}

output "resources" {
  description = "Full azurerm_resource_group resource objects, keyed by input map key."
  value       = azurerm_resource_group.this
}
