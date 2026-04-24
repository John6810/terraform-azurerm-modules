###############################################################
# MODULE: AvdSessionHost - Outputs
###############################################################

output "vm_ids" {
  description = "Map of VM suffix => VM resource ID"
  value       = { for k, v in azurerm_windows_virtual_machine.this : k => v.id }
}

output "vm_names" {
  description = "Map of VM suffix => VM resource name"
  value       = { for k, v in azurerm_windows_virtual_machine.this : k => v.name }
}

output "computer_names" {
  description = "Map of VM suffix => Windows computer (hostname)"
  value       = { for k, v in azurerm_windows_virtual_machine.this : k => v.computer_name }
}

output "private_ips" {
  description = "Map of VM suffix => NIC private IP"
  value       = { for k, v in azurerm_network_interface.this : k => v.private_ip_address }
}

output "principal_ids" {
  description = "Map of VM suffix => SystemAssigned identity principal ID (for RBAC grants)"
  value       = { for k, v in azurerm_windows_virtual_machine.this : k => v.identity[0].principal_id }
}
