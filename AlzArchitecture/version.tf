terraform {
  required_version = ">= 1.5.0"
  required_providers {
    alz = {
      source  = "Azure/alz"
      version = "~> 0.19"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
