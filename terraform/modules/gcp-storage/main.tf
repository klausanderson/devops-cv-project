# GCS bucket used for CNPG (CloudNativePG) Barman/WAL backups.
# Bucket-level IAM (who can write to it) is granted separately by the
# gcp-workload-identity module - keeps "what the bucket is" decoupled
# from "who can touch it".
resource "google_storage_bucket" "this" {
  name                        = var.bucket_name
  project                     = var.project_id
  location                    = var.location
  storage_class                = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  versioning {
    enabled = var.versioning_enabled
  }

  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }
}
