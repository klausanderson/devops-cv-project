variable "project_id" {
  type = string
}

variable "location" {
  description = "GCS location - can be a region (europe-central2) or multi-region"
  type        = string
}

variable "bucket_name" {
  description = "Must be globally unique across all of GCS"
  type        = string
}

variable "versioning_enabled" {
  type    = bool
  default = true
}

variable "force_destroy" {
  description = "Allows `terraform destroy` to delete a non-empty bucket. Keep false outside of learning environments."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  type    = number
  default = 30
}
