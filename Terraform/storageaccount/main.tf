terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  # backend "azurerm" {
  #     resource_group_name  = "rg-test"
  #     storage_account_name = "sabctest"
  #     container_name       = "tfstate"
  #     key                  = "terraform.tfstate"
  # }
}

provider "azurerm" {
   features {}
  }

# resource "azurerm_resource_group" "storage" {
#  name     = var.resource_group_name
#  location = var.location
# }

resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

#variable "resource_group_name" {
#  type    = string
#  default = "rg-test"
#}

# variable "location" {
#   type    = string
#   default = "North Europe"
# }

# variable "storage_account_name" {
#   type    = string
#   default = "mystorageaccount86"
# }

# variable "tags" {
#   type    = map(string)
#   default = {}
# }
