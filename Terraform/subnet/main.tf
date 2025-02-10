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
# Azure Virtual Network
# resource "azurerm_virtual_network" "example_vnet" {
#   name                = "vnet-${var.client_name}-${var.environment}-${var.location}"
#   address_space       = ["10.0.0.0/16"]
#   location            = var.location
#   resource_group_name = var.resourcegroup
# }

resource "azurerm_subnet" "example_subnet1" {
  name                 = "subnetnew"
  resource_group_name  = var.resourcegroup
  virtual_network_name = var.virtual_network_name
  address_prefixes     = ["10.0.4.0/24"]
}
