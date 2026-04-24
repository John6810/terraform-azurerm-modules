###############################################################
# MODULE: AvdScalingPlan - Outputs
###############################################################

output "id" {
  description = "Scaling plan resource ID"
  value       = azurerm_virtual_desktop_scaling_plan.this.id
}

output "name" {
  description = "Scaling plan name"
  value       = azurerm_virtual_desktop_scaling_plan.this.name
}
