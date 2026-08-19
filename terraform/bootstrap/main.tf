# Run this ONCE, by hand, before anything under environments/. It creates
# the GCS bucket and (optionally) the Azure Storage Account that can hold
# Terraform state for environments/dev - you can't have that environment's
# own backend block create its own state store (classic chicken-and-egg),
# so this tiny config uses a local backend instead.
#
#   cd bootstrap
#   terraform init
#   terraform apply
#
# Its state file (terraform.tfstate) can stay local, or you can move it
# into the bucket it just created after the fact with `terraform init
# -migrate-state` once you've added a backend block here too - optional.
#
# The Azure storage account below is created for parity but isn't wired up
# as the active backend yet - environments/dev/backend.tf still points at
# "gcs". To actually move dev's state to Azure: add a `backend "azurerm"`
# block there (using the resource group / storage account / container names
# from this file) and run `terraform init -migrate-state`.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
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

resource "azurerm_resource_group" "tf_state" {
  name     = var.azure_tf_state_resource_group_name
  location = var.azure_location
}

resource "azurerm_storage_account" "tf_state" {
  name                     = var.azure_tf_state_storage_account_name
  resource_group_name     = azurerm_resource_group.tf_state.name
  location                 = azurerm_resource_group.tf_state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tf_state" {
  name                  = var.azure_tf_state_container_name
  storage_account_name = azurerm_storage_account.tf_state.name
  container_access_type = "private"
}

# Azure lifecycle management is day-based, not count-based like the GCS
# num_newer_versions rule above - this trims old blob versions instead of
# keeping a fixed count.
resource "azurerm_storage_management_policy" "tf_state" {
  storage_account_id = azurerm_storage_account.tf_state.id

  rule {
    name    = "expire-old-state-versions"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      version {
        delete_after_days_since_creation = var.azure_tf_state_version_retention_days
      }
    }
  }
}
