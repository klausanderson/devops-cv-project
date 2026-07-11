output "gsa_email" {
  value = google_service_account.this.email
}

output "gsa_name" {
  value = google_service_account.this.name
}

output "ksa_annotation" {
  description = "Copy this onto the Kubernetes ServiceAccount as iam.gke.io/gcp-service-account"
  value       = google_service_account.this.email
}
