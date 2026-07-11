variable "project_id" {
  type = string
}

variable "gsa_account_id" {
  description = "GSA account_id, e.g. eso-secret-reader (max 30 chars, becomes <id>@<project>.iam.gserviceaccount.com)"
  type        = string
}

variable "gsa_display_name" {
  type = string
}

variable "ksa_namespace" {
  description = "Kubernetes namespace of the ServiceAccount this GSA is federated with"
  type        = string
}

variable "ksa_name" {
  description = "Kubernetes ServiceAccount name. Must exactly match the KSA that carries the iam.gke.io/gcp-service-account annotation."
  type        = string
}

variable "project_iam_roles" {
  description = "Project-level IAM roles to grant this GSA"
  type        = list(string)
  default     = []
}

variable "bucket_iam_bindings" {
  description = "Bucket-scoped IAM roles to grant this GSA"
  type = list(object({
    bucket_name = string
    role        = string
  }))
  default = []
}
