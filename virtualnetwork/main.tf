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
resource "azurerm_virtual_network" "example_vnet" {
  name                = "vnet-${var.vn_name}${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.virtual_netwok_rg_name
}

resource "azurerm_subnet" "example_subnet1" {
  name                 = "${var.subnet_name}${var.environment}"
  resource_group_name  = var.virtual_netwok_rg_name
  virtual_network_name = azurerm_virtual_network.example_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "outbountsubnet1" {
  name                 = "${var.subnet_name2}${var.environment}"
  resource_group_name  = var.virtual_netwok_rg_name
  virtual_network_name = azurerm_virtual_network.example_vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "example-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}



# resource "azurerm_private_dns_zone" "example" {
#   name                = "privatelink.blob.core.windows.net"
#   resource_group_name = var.virtual_netwok_rg_name
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "example" {
#   name                  = "example-link"
#   resource_group_name   = var.virtual_netwok_rg_name
#   private_dns_zone_name = azurerm_private_dns_zone.example.name
#   virtual_network_id    = azurerm_virtual_network.example_vnet.id
#   # data.azurerm_virtual_network.virtual_network_data.id
#   #var.virtual_network_id
# }