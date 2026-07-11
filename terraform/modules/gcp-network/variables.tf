variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the subnet (e.g. europe-central2)"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC (equivalent to `gcloud compute networks create`)"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "subnet-1"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
}
