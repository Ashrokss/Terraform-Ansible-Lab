# ============================================================================
# Azure Provider Configuration
# ============================================================================
# This file configures the required providers for:
#   - AzureRM: Azure Resource Manager for infrastructure provisioning
#   - AzureAD: Azure Active Directory for Service Principal creation
#   - TLS:     For generating SSH key pairs
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Azure Resource Manager Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
