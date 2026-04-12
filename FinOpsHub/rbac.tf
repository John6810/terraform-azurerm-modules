###############################################################
# RBAC — Role Assignments
###############################################################

# ADF Managed Identity → Storage Blob Data Contributor
resource "azurerm_role_assignment" "adf_storage_blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

# ADF Managed Identity → Reader on Storage Account
resource "azurerm_role_assignment" "adf_storage_reader" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Reader"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

# Azure Cost Management Exports SP → Storage Blob Data Contributor
resource "azurerm_role_assignment" "cost_mgmt_exports_storage" {
  count = var.cost_management_exports_principal_id != null ? 1 : 0

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.cost_management_exports_principal_id
}

# ADX Cluster → Storage Blob Data Contributor (for data ingestion)
resource "azurerm_role_assignment" "adx_storage_blob" {
  count = var.enable_data_explorer ? 1 : 0

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_kusto_cluster.this[0].identity[0].principal_id
}

# ADF Managed Identity → ADX Database Ingestor (Ingestion DB)
resource "azurerm_kusto_database_principal_assignment" "adf_ingestion" {
  count = var.enable_data_explorer ? 1 : 0

  name                = "adf-ingestor"
  resource_group_name = azurerm_resource_group.this.name
  cluster_name        = azurerm_kusto_cluster.this[0].name
  database_name       = azurerm_kusto_database.ingestion[0].name
  tenant_id           = azurerm_data_factory.this.identity[0].tenant_id
  principal_id        = azurerm_data_factory.this.identity[0].principal_id
  principal_type      = "App"
  role                = "Ingestor"
}

# ADF Managed Identity → ADX Database Viewer (Hub DB)
resource "azurerm_kusto_database_principal_assignment" "adf_hub_viewer" {
  count = var.enable_data_explorer ? 1 : 0

  name                = "adf-viewer"
  resource_group_name = azurerm_resource_group.this.name
  cluster_name        = azurerm_kusto_cluster.this[0].name
  database_name       = azurerm_kusto_database.hub[0].name
  tenant_id           = azurerm_data_factory.this.identity[0].tenant_id
  principal_id        = azurerm_data_factory.this.identity[0].principal_id
  principal_type      = "App"
  role                = "Viewer"
}
