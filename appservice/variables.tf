variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
}

variable "app_service_name" {
  description = "Name of the App Service"
  type        = string
}

variable "cosmosdb_account_name" {
  description = "Name of the Cosmos DB account"
  type        = string
}

variable "location" {
  description = "Azure region where the resources will be provisioned"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}
