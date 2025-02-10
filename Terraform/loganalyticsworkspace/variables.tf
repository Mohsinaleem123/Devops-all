variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "location" {
  description = "Azure region where the workspace will be provisioned"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "retention_in_days" {
  description = "Number of days to retain data in the Log Analytics workspace"
  type        = number
  default     = 30
}
