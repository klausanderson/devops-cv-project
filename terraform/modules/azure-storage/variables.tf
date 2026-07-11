variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  description = "3-24 chars, lowercase letters and numbers only, must be globally unique across all of Azure"
  type        = string
}

variable "container_name" {
  type    = string
  default = "cnpg-backups"
}

variable "account_tier" {
  type    = string
  default = "Standard"
}

variable "replication_type" {
  type    = string
  default = "LRS"
}
