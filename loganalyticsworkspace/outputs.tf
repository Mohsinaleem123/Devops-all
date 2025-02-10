output "workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.example.id
}

output "workspace_primary_key" {
  description = "Primary key for accessing the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.example.primary_shared_key
}

output "workspace_workspace_id" {
  description = "Workspace ID for accessing the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.example.workspace_id
}
