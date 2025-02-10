# main.tf
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.0.0"
    }
  }
}


provider "azurerm" {
   features {}
  }

resource "azurerm_cosmosdb_account" "my_cosmosdb" {
  name                = var.cosmosdb_account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  consistency_policy {
    consistency_level = "Session"
  }

  enable_automatic_failover = false

  tags = var.tags

  geo_location {
    location          = var.location
    failover_priority = 0
  }
}


output "cosmosdb_endpoint" {
  value = azurerm_cosmosdb_account.example.endpoint
}

output "cosmosdb_primary_master_key" {
  value = azurerm_cosmosdb_account.example.primary_master_key
}
