variable "location" {
  description = "Azure region to use."
  type        = string 
  default = "northeurope"
}

variable "client_name" {
  description = "Client name/account used in naming"
  type        = string
  default = "testvnet"
}

variable "environment" {
  description = "Project environment"
  type        = string
  default = "PROD"
}

variable "resourcegroup" {
  description = "Project stack name"
  type        = string
  default = "rg-test"
}


variable "virtual_network_name" {
  description = "Project stack name"
  type        = string
  default = "vnet-testvnet-PROD-northeurope"
  
}