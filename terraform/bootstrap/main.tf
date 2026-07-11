# Run this ONCE, by hand, before anything under environments/. It creates
# the GCS bucket that will hold Terraform state for environments/dev -
# you can't have that environment's own backend "gcs" block create its own
# state bucket (classic chicken-and-egg), so this tiny config uses a local
# backend instead.
#
#   cd bootstrap
#   terraform init
#   terraform apply
#
# Its state file (terraform.tfstate) can stay local, or you can move it
# into the bucket it just created after the fact with `terraform init
# -migrate-state` once you've added a backend block here too - optional.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

resource "google_storage_bucket" "tf_state" {
  name                        = var.tf_state_bucket_name
  project                     = var.gcp_project_id
  location                    = var.gcp_region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
      with_state          = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}
