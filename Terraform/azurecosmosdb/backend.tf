terraform {
  backend "azurerm" {
    resource_group_name   = "rg-terraform"
    storage_account_name  = "saterraformiac"
    container_name        = "tfstatefiles"
    key                   = "iac.tfstate"
    client_id             = "3a17daa0-25cc-453c-8e03-ff026907877c"
    client_secret         = ""
    tenant_id             = "5c694bc3-decd-4a0c-b21d-f5c01aa93790"
    subscription_id       = "ef3436d9-4a77-4420-9751-78481b8475d3"

  }
}