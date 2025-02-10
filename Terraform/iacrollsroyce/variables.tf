variable "projectName" {
  description = "Name of the project acssociated with this RG"
  default     = "rgdropdxnew"
}

variable "location" {
  description = "location of the RG"
  default     = "UK South"
}

variable "environment"{
  description = "The name for the environment"
  default     = "dev"
}

variable "tags" {
  default = { }
}


variable "storage_account_name" {
  type    = string
  default = "sadropdxcnew"
}
variable "storage_account_name_second" {
  type    = string
  default = "sadeploymentdxcnew"
}


########################################################################
variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  default = "ladxnew"
}


variable "retention_in_days" {
  description = "Number of days to retain data in the Log Analytics workspace"
  type        = number
  default     = 30
}


#########################################################################
variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default = "aplan-deploymentnew-dxc-"
}

variable "app_service_name" {
  description = "Name of the App Service"
  type        = string
  default = "app-deploymentnew-dxc-fe-"
}

variable "app_service_name_two" {
  description = "Name of the App Service"
  type        = string
  default = "app-deploymentnew-dxc-be-"
}



#################################################################
variable "cosmosdb_account_name" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "mdb-deploymentnew-dxc-"
}


##################################################################

variable "frontendep" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "frontendep"
}


variable "backendep" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "backendep"
}

variable "subnet_name" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "drpdx-fe-"
}


variable "outbound_subnet_name" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "outbound-fe-"
}


variable "virtual_network_name" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "vnet-drpxtest-vn-"
}
variable "virtual_netwok_rg_name" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "RG-VNETDRX"
}
variable "virtual_network_id" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "/subscriptions/7ccafe18-7f09-4263-afbc-35b14a576e93/resourceGroups/RG-VNETDRX/providers/Microsoft.Network/virtualNetworks/drpxtest-vn"
}
#########################################################################################################################################

variable "appconf_name" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "app-dxvn-"
}

variable "appconfig_pep" {
  description = "The name of the Cosmos DB account."
  type        = string
  default = "app-dxvn-"
}
#drpxtest-vn