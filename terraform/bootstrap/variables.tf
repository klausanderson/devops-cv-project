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
