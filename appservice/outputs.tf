output "app_service_url" {
  description = "URL of the deployed App Service"
  value       = azurerm_app_service.example.default_site_hostname
}

output "cosmosdb_endpoint" {
  description = "Endpoint for accessing the Cosmos DB account"
  value       = azurerm_cosmosdb_account.example.endpoint
}

output "cosmosdb_primary_key" {
  description = "Primary key for accessing the Cosmos DB account"
  value       = azurerm_cosmosdb_account.example.primary_master_key
}
