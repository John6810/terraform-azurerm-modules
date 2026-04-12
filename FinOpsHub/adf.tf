###############################################################
# Azure Data Factory — ETL orchestration
###############################################################

resource "azurerm_data_factory" "this" {
  name                            = local.adf_name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.location
  public_network_enabled          = var.enable_public_access
  managed_virtual_network_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

###############################################################
# Linked Service — ADLS Gen2 Storage
###############################################################
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "storage" {
  name                 = "ls_storage"
  data_factory_id      = azurerm_data_factory.this.id
  url                  = azurerm_storage_account.this.primary_dfs_endpoint
  use_managed_identity = true
}

###############################################################
# Dataset — Parquet source (msexports container)
###############################################################
resource "azurerm_data_factory_dataset_parquet" "msexports" {
  name                = "ds_msexports"
  data_factory_id     = azurerm_data_factory.this.id
  linked_service_name = azurerm_data_factory_linked_service_data_lake_storage_gen2.storage.name

  compression_codec = "snappy"

  azure_blob_fs_location {
    file_system = "msexports"
  }
}

###############################################################
# Dataset — Parquet sink (ingestion container) with Snappy
###############################################################
resource "azurerm_data_factory_dataset_parquet" "ingestion" {
  name                = "ds_ingestion"
  data_factory_id     = azurerm_data_factory.this.id
  linked_service_name = azurerm_data_factory_linked_service_data_lake_storage_gen2.storage.name
  compression_codec   = "snappy"

  parameters = {
    folderPath = ""
  }

  azure_blob_fs_location {
    file_system          = "ingestion"
    path                 = "@dataset().folderPath"
    dynamic_path_enabled = true
  }
}

###############################################################
# Pipeline — msexports ETL (export → ingestion container)
###############################################################
resource "azurerm_data_factory_pipeline" "msexports_etl" {
  name            = "msexports_ETL"
  data_factory_id = azurerm_data_factory.this.id
  activities_json = file("${path.module}/pipelines/msexports_etl.json")

  parameters = {
    folderPath     = ""
    datasetType    = ""
    datasetVersion = ""
  }

  depends_on = [
    azurerm_data_factory_dataset_parquet.msexports,
    azurerm_data_factory_dataset_parquet.ingestion,
  ]
}

###############################################################
# Trigger — Blob event on msexports manifest
###############################################################
resource "azurerm_data_factory_trigger_blob_event" "msexports" {
  name                  = "msexports_ManifestAdded"
  data_factory_id       = azurerm_data_factory.this.id
  storage_account_id    = azurerm_storage_account.this.id
  events                = ["Microsoft.Storage.BlobCreated"]
  blob_path_begins_with = "/msexports/blobs/"
  blob_path_ends_with   = "manifest.json"
  ignore_empty_blobs    = true
  activated             = true

  pipeline {
    name = azurerm_data_factory_pipeline.msexports_etl.name
    parameters = {
      folderPath     = "@triggerBody().folderPath"
      datasetType    = "costs"
      datasetVersion = "1.0"
    }
  }

  depends_on = [azurerm_role_assignment.adf_storage_blob]
}
