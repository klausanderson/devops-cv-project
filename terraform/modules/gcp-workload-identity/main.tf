# Generic GSA <-> KSA Workload Identity module. Instantiated twice from
# environments/dev/gcp.tf: once for ESO (Secret Manager access) and once
# for CNPG (GCS backup bucket access) - same mechanism, different roles.

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.gsa_account_id
  display_name = var.gsa_display_name
}

# Project-level IAM roles, e.g. roles/secretmanager.secretAccessor for ESO
resource "google_project_iam_member" "roles" {
  for_each = toset(var.project_iam_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

# Bucket-scoped IAM roles, e.g. roles/storage.objectAdmin for CNPG backups.
# This is the Terraform equivalent of the `gcloud storage buckets
# add-iam-policy-binding` migration already in progress in the Taskfile
# (replacing the old `gsutil iam ch` approach).
resource "google_storage_bucket_iam_member" "bucket_roles" {
  for_each = { for b in var.bucket_iam_bindings : "${b.bucket_name}-${b.role}" => b }

  bucket = each.value.bucket_name
  role   = each.value.role
  member = "serviceAccount:${google_service_account.this.email}"
}

# The actual Workload Identity binding: lets the Kubernetes ServiceAccount
# impersonate this GSA. The federated member string below is the same
# string GKE derives on its own - nothing to register on the GKE side.
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.this.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "serviceAccount:${var.project_id}.svc.id.goog[${var.ksa_namespace}/${var.ksa_name}]"
}
