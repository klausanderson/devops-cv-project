variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "vnet_address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_name" {
  type    = string
  default = "subnet-1"
}

variable "subnet_address_prefix" {
  type = string
}
