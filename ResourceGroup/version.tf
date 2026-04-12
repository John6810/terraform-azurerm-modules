###############################################################
# TERRAFORM BLOCK
# Description: Specifies required Terraform and provider versions
# Terraform version: >= 1.5.0 (improved optional() support)
# AzureRM provider: ~> 4.0
# Time provider: >= 0.9.0 (for time_static resource)
###############################################################
terraform {
  # Minimum required Terraform version
  required_version = ">= 1.5.0"

  # Required providers with minimum versions
  required_providers {
    # Azure Resource Manager provider
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # Time provider (for timestamps)
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}
