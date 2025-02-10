variable "resource_group_name" {
 type    = string
 default = "rg-test"
}
variable "environment" {
type    = string
  default = "prod"

}
variable "location" {
  type    = string
  default = "North Europe"
}

variable "storage_account_name" {
  type    = string
  default = "mystorageaccount86"
}

variable "tags" {
  type    = map(string)
  default = {}
}
