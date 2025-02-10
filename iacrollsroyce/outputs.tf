
output "resource_group_name" {
  description = "The name of the newly created RG"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "The location of the newly created RG"
  value       = azurerm_resource_group.rg.location
}

output "resource_group_id"{
  description = "The id of the newly created RG"
  value       = azurerm_resource_group.rg.id
}

output "storage_account_name" {
  description = "The id of the newly created storage Account"
  value = azurerm_storage_account.storageone.name
}

output "storage_account_location" {
  description = "The id of the newly created storage Account"
  value = azurerm_storage_account.storageone.location
}

output "storage_account_id" {
  description = "The id of the newly created storage Account"
  value = azurerm_storage_account.storageone.id
}

output "storage_account_name_two" {
  description = "The id of the newly created storage Account"
  value = azurerm_storage_account.storagetwo.name
}

output "storage_account_id_two" {
  description = "The id of the newly created storage Account"
  value = azurerm_storage_account.storagetwo.id
}
#######################################################################
output "workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.example.id
}

# output "workspace_primary_key" {
#   description = "Primary key for accessing the Log Analytics workspace"
#   value       = azurerm_log_analytics_workspace.example.primary_shared_key
# }

output "workspace_workspace_id" {
  description = "Workspace ID for accessing the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.example.workspace_id
}



################################################################################3
#appserviceplan
output "app_service_url" {
  value = azurerm_app_service.appserviceone.default_site_hostname
}
output "app_service_url_two" {
  value = azurerm_app_service.appservicetwo.default_site_hostname
}