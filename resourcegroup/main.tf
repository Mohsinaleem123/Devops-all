 terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 3.10.0"
    }
  }
}
provider "azurerm" {
   features {}
  }

# Constructed names of resources
locals {
    resourceGroupName           = "rg-${var.projectName}-${var.environment}"
    tags = {
    environment = "development"
    costcenter  = "it"
    IaC  = "Terraform"
    Owner = "Aamir Saleem"
  }
}

 #Create the Resource Group
resource "azurerm_resource_group" "rg" {
    name     = local.resourceGroupName
    location = "${var.location}"
    tags = merge({ "ResourceName" = format("%s", local.resourceGroupName) }, local.tags, var.tags )
}