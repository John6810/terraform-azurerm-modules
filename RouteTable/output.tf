###############################################################
# MODULE: RouteTable - Outputs
###############################################################

output "id" {
  description = "The route table ID"
  value       = azurerm_route_table.this.id
}

output "name" {
  description = "The route table name"
  value       = azurerm_route_table.this.name
}

output "routes" {
  description = "The route definitions applied to the route table"
  value       = azurerm_route_table.this.route
}

output "resource" {
  description = "The complete route table resource object"
  value       = azurerm_route_table.this
}
