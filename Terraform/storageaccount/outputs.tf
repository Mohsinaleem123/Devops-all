output "storage_account_name" {
  description = "The id of the newly created storage Account"
  value = azurerm_storage_account.storage.name
}

output "storage_account_location" {
  description = "The id of the newly created storage Account"
  value = azurerm_storage_account.storage.location
}

output "storage_account_id" {
  description = "The id of the newly created storage Account"
  value = azurerm_storage_account.storage.id
}

# output "storage_account_primary_location" {
#   description = "The primary location of the storage account"
#   value       = one(module.storage[*].storage_account_primary_location)
# }

# output "storage_account_primary_blob_endpoint" {
#   description = "The endpoint URL for blob storage in the primary location"
#   value       = one(module.storage[*].storage_account_primary_blob_endpoint)
# }

# output "storage_account_primary_web_endpoint" {
#   description = "The endpoint URL for web storage in the primary location"
#   value       = one(module.storage[*].storage_account_primary_web_endpoint)
# }

# output "storage_account_primary_web_host" {
#   description = "The hostname with port if applicable for web storage in the primary location"
#   value       = one(module.storage[*].storage_account_primary_web_host)
# }

# output "storage_primary_connection_string" {
#   description = "The primary connection string for the storage account"
#   value       = one(module.storage[*].storage_primary_connection_string)
#   sensitive   = true
# }

# output "storage_primary_access_key" {
#   description = "The primary access key for the storage account"
#   value       = one(module.storage[*].storage_primary_access_key)
#   sensitive   = true
# }

# output "storage_secondary_access_key" {
#   description = "The primary access key for the storage account"
#   value       = one(module.storage[*].storage_secondary_access_key)
#   sensitive   = true
# }

# output "containers" {
#   description = "Map of containers"
#   value       = one(module.storage[*].containers)
# }
