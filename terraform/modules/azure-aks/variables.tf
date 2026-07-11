variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "service_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.1.0.10"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "node_os_disk_type" {
  type    = string
  default = "Managed"
}

variable "node_os_disk_size_gb" {
  type    = number
  default = 50
}

variable "node_count" {
  type    = number
  default = 2
}

variable "enable_gateway_api" {
  description = "Applies the Gateway API add-on via az CLI local-exec (see main.tf note). Set false if you don't want a local-exec provisioner in your plan."
  type        = bool
  default     = true
}
