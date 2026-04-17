###############################################################
# MODULE: FlowLogs - Outputs
###############################################################

output "ids" {
  description = "Map of VNet key to flow log resource ID"
  value       = { for k, v in azurerm_network_watcher_flow_log.this : k => v.id }
}

output "names" {
  description = "Map of VNet key to flow log resource name"
  value       = { for k, v in azurerm_network_watcher_flow_log.this : k => v.name }
}
