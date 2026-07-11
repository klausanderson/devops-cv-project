output "cluster_id" {
  value = google_container_cluster.this.id
}

output "cluster_name" {
  value = google_container_cluster.this.name
}

output "endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}

output "ca_certificate" {
  value     = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "workload_pool" {
  value = google_container_cluster.this.workload_identity_config[0].workload_pool
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --zone ${var.zone} --project ${var.project_id}"
}
