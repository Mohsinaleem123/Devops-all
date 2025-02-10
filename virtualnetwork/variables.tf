variable "location" {
  description = "Azure region to use."
  type        = string 
  default = "UK South"
}

variable "vn_name" {
  description = "Client name/account used in naming"
  type        = string
  default = "drpxtest-vn-"
}

variable "environment" {
  description = "Project environment"
  type        = string
  default = "dev"
}

variable "virtual_netwok_rg_name" {
  description = "Project stack name"
  type        = string
  default = "RG-VNETDRX"
}


variable "subnet_name" {
  description = "Project stack name"
  type        = string
  default = "drpdx-fe-"
}

variable "subnet_name2" {
  description = "Project stack name"
  type        = string
  default = "outbound-fe-"
}

