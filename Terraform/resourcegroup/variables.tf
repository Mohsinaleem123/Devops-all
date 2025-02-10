variable "projectName" {
  description = "Name of the project acssociated with this RG"
  default     = "terraform"
}

variable "location" {
  description = "location of the RG"
  default     = "North Europe"
}

variable "environment"{
  description = "The name for the environment"
  default     = "dev"
}

variable "tags" {
  default = { }
}