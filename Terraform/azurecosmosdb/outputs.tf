# outputs.tf

output "cosmosdb_endpoint" {
  description = "The endpoint for the Cosmos DB account."
  value       = azurerm_cosmosdb_account.example.endpoint
}

output "cosmosdb_primary_master_key" {
  description = "The primary master key for the Cosmos DB account."
  value       = azurerm_cosmosdb_account.example.primary_master_key
}
