# --- GKE ---
output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "gke_get_credentials_command" {
  value = module.gke.get_credentials_command
}

output "gcp_eso_gsa_email" {
  value = module.gcp_eso_identity.gsa_email
}

output "gcp_cnpg_gsa_email" {
  value = module.gcp_cnpg_backup_identity.gsa_email
}

output "cnpg_gcs_bucket" {
  value = module.gcp_cnpg_backup_bucket.bucket_name
}

# --- AKS ---
output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_get_credentials_command" {
  value = module.aks.get_credentials_command
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "azure_eso_uami_client_id" {
  value = module.azure_eso_identity.client_id
}

output "azure_cnpg_uami_client_id" {
  value = module.azure_cnpg_backup_identity.client_id
}

output "cnpg_azure_container" {
  value = module.azure_cnpg_backup_storage.container_name
}
