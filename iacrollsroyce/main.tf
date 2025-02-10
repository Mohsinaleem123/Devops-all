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



resource "azurerm_storage_account" "storageone" {
  name                     = "${var.storage_account_name}${var.environment}"
  resource_group_name      =local.resourceGroupName
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = var.tags
  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_storage_account" "storagetwo" {
  name                     = "${var.storage_account_name_second}${var.environment}"
  resource_group_name      =local.resourceGroupName
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
  depends_on = [azurerm_resource_group.rg]
}



resource "azurerm_log_analytics_workspace" "example" {
  name                =  "${var.workspace_name}${var.environment}"
  location            = var.location
  resource_group_name = local.resourceGroupName

  sku  = "PerGB2018"
  

  retention_in_days = var.retention_in_days
  depends_on = [azurerm_resource_group.rg]
}
#####################################################################
resource "azurerm_app_service_plan" "appserviceplan" {
  name                = "${var.app_service_plan_name}${var.environment}"
  location            = var.location
  resource_group_name = local.resourceGroupName
  kind                = "Windows"
  reserved            = false

  sku {
    tier = "Standard"
    size = "S1"
  }
  depends_on = [azurerm_resource_group.rg]
}
#azurerm_windows_web_app 
#azurerm_app_service
resource "azurerm_app_service" "appserviceone" {
  name                = "${var.app_service_name}${var.environment}"
  location            = var.location
  resource_group_name = local.resourceGroupName
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id
  #kind                = "Windows"
 depends_on = [azurerm_resource_group.rg ,
  azurerm_app_service_plan.appserviceplan
  ]
  #   site_config {
  #   dotnet_framework_version = "v5.0"  # Specify the .NET version
  # }
 site_config {
    use_32_bit_worker_process = "true"
    ftps_state                = "Disabled"
    always_on                 = "true"
     dotnet_framework_version = "v5.0"
  }  

  app_settings = {
      "Environment": "Development",
    "mongodb": "moggodb://localhost:27017",
    "keyvaulturl": "https://rrdeploykv16557.vault.azure.net/",
  }
    connection_string {
    name  = "keyvaulturl"
    type  = "Custom"
    value = "https://rrdeploykv16557.vault.azure.net/"
  }
  
  # site_config {
  #   always_on        = true
  #   linux_fx_version = "DOCKER|<docker-image>"
  # }
}
resource "azurerm_app_service" "appservicetwo" {
  name                = "${var.app_service_name_two}${var.environment}"
  location            = var.location
  resource_group_name = local.resourceGroupName
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id
   depends_on = [azurerm_resource_group.rg ,
  azurerm_app_service_plan.appserviceplan
  ]
  #kind                = "Windows"
  #  site_config {
  #   dotnet_framework_version = "v5.0"  # Specify the .NET version
  # }
    
site_config {
    use_32_bit_worker_process = "true"
    ftps_state                = "Disabled"
    always_on                 = "true"
     dotnet_framework_version = "v5.0"
  }  

  app_settings = {
      "Environment": "Development",
    "mongodb": "moggodb://localhost:27017",
    "keyvaulturl": "https://rrdeploykv16557.vault.azure.net/",
  }
    connection_string {
    name  = "keyvaulturl"
    type  = "Custom"
    value = "https://rrdeploykv16557.vault.azure.net/"
  }
 



}
#################################################################
# resource "azurerm_subnet" "endpoint" {
#   name                 = "${var.subnet_name}"
#   resource_group_name  = "${var.virtual_netwok_rg_name}"
#   virtual_network_name = "${var.virtual_network_name}"
#   address_prefixes     = ["10.0.2.0/24"]
# }

data "azurerm_virtual_network" "virtual_network_data" {
  name                = "${var.virtual_network_name}${var.environment}"
  resource_group_name = var.virtual_netwok_rg_name
}

data "azurerm_subnet" "examplesub" {
  name                 = "${var.subnet_name}${var.environment}"
  virtual_network_name = "${var.virtual_network_name}${var.environment}"
  resource_group_name  =var.virtual_netwok_rg_name
}

output "subnet_id" {
  value = data.azurerm_subnet.examplesub.id
}

resource "azurerm_private_endpoint" "endpointone" {
  name                = "${var.frontendep}${var.environment}"
  location            = var.location
  resource_group_name = var.virtual_netwok_rg_name
  subnet_id           = data.azurerm_subnet.examplesub.id

  private_service_connection {
    name                           = "privateserviceconnection"
    private_connection_resource_id = azurerm_app_service.appserviceone.id
     subresource_names = ["sites"]
    is_manual_connection           = false
   
  }
   private_dns_zone_group {
    name                 = "example-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.example.id]
  }
}

resource "azurerm_private_endpoint" "endpointtwo" {
  name                = "${var.backendep}${var.environment}"
  location            = var.location
  resource_group_name = var.virtual_netwok_rg_name
  subnet_id           = data.azurerm_subnet.examplesub.id

  private_service_connection {
    name                           = "privateserviceconnectionbackend"
    private_connection_resource_id = azurerm_app_service.appservicetwo.id
     subresource_names = ["sites"]
    is_manual_connection           = false
   
  }
   private_dns_zone_group {
    name                 = "example-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.example.id]
  }
}
###

resource "azurerm_private_dns_zone" "example" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.virtual_netwok_rg_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "example-link"
  resource_group_name   = var.virtual_netwok_rg_name
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = data.azurerm_virtual_network.virtual_network_data.id
  #var.virtual_network_id
}
###############
data "azurerm_subnet" "outboundsub" {
  name                 = "${var.outbound_subnet_name}${var.environment}"
  virtual_network_name = "${var.virtual_network_name}${var.environment}"
  resource_group_name  =var.virtual_netwok_rg_name
}
resource "azurerm_app_service_virtual_network_swift_connection" "example" {
  app_service_id = azurerm_app_service.appserviceone.id
  subnet_id      = data.azurerm_subnet.outboundsub.id
}

######################################################################


resource "azurerm_app_configuration" "app_config" {
  name                = "${var.appconf_name}${var.environment}"
  location            =var.location # Replace with your desired location
  resource_group_name = local.resourceGroupName  # Replace with your resource group name
  public_network_access      = "Enabled"
   sku                        = "standard"
    depends_on = [azurerm_resource_group.rg ,
  azurerm_app_service_plan.appserviceplan
  ]
}

resource "azurerm_private_endpoint" "appconfig_pep" {
  name                = "${var.appconfig_pep}${var.environment}"
  location            = var.location # Replace with your desired location
  resource_group_name = var.virtual_netwok_rg_name # Replace with your resource group name
  subnet_id           =  data.azurerm_subnet.examplesub.id
 # Replace with the ID of your subnet

  private_service_connection {
    name                   = "app-config-pep-conn"
    is_manual_connection  = false
    subresource_names     = ["configurationStores"]
    private_connection_resource_id =azurerm_app_configuration.app_config.id  # Replace with the ID of your private connection
  }

  depends_on = [azurerm_app_configuration.app_config]
}





###########################################################

# resource "azurerm_cosmosdb_account" "my_cosmosdb" {
#   name                = "${var.cosmosdb_account_name}${var.environment}"
#   location            = var.location
#   resource_group_name = local.resourceGroupName
#   offer_type          = "Standard"
#   kind                = "MongoDB"

#   consistency_policy {
#     consistency_level = "Session"
#   }

#   enable_automatic_failover = false

#   tags = var.tags

#   geo_location {
#     location          = var.location
#     failover_priority = 0
#   }
# }
