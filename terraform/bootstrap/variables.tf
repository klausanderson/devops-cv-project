variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "europe-central2"
}

variable "tf_state_bucket_name" {
  description = "Must be globally unique across all of GCS"
  type        = string
  default     = "klaus-devops-journey-tfstate"
}

variable "azure_subscription_id" {
  type = string
}

variable "azure_location" {
  type    = string
  default = "polandcentral"
}

variable "azure_tf_state_resource_group_name" {
  type    = string
  default = "azure-devops-learning-tfstate"
}

variable "azure_tf_state_storage_account_name" {
  description = "3-24 chars, lowercase letters/numbers only, must be globally unique across all of Azure"
  type        = string
  default     = "klausdevopstfstate"
}

variable "azure_tf_state_container_name" {
  type    = string
  default = "tfstate"
}

variable "azure_tf_state_version_retention_days" {
  description = "Old blob versions older than this are deleted (Azure's lifecycle policy is day-based, unlike GCS's count-based rule above)"
  type        = number
  default     = 90
}
