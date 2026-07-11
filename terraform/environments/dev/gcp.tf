# Replaces gcp:02-enable-apis
resource "google_project_service" "apis" {
  for_each = toset(var.gcp_apis)

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}

# Replaces gcp:04-create-vpc + gcp:05-create-subnet
module "gcp_network" {
  source = "../../modules/gcp-network"

  project_id   = var.gcp_project_id
  region       = var.gcp_region
  network_name = var.gcp_network_name
  subnet_cidr  = var.gcp_subnet_cidr

  depends_on = [google_project_service.apis]
}

# Replaces gcp:06-create-cluster
module "gke" {
  source = "../../modules/gcp-gke"

  project_id            = var.gcp_project_id
  region                = var.gcp_region
  zone                  = var.gcp_zone
  cluster_name          = var.gke_cluster_name
  network_self_link     = module.gcp_network.network_self_link
  subnetwork_self_link  = module.gcp_network.subnet_self_link
  machine_type          = var.gke_machine_type
  disk_type             = var.gke_disk_type
  disk_size_gb          = var.gke_disk_size_gb
  node_count            = var.gke_node_count
}

# CNPG backup bucket (new - not in the original Taskfile, but needed for
# the CNPG -> GCS backup flow already in progress)
module "gcp_cnpg_backup_bucket" {
  source = "../../modules/gcp-storage"

  project_id            = var.gcp_project_id
  location              = var.gcp_region
  bucket_name           = var.cnpg_backup_bucket_name
  backup_retention_days = var.cnpg_backup_retention_days

  depends_on = [google_project_service.apis]
}

# ESO -> GCP Secret Manager Workload Identity binding
module "gcp_eso_identity" {
  source = "../../modules/gcp-workload-identity"

  project_id        = var.gcp_project_id
  gsa_account_id    = "eso-secret-reader"
  gsa_display_name  = "External Secrets Operator - Secret Manager reader"
  ksa_namespace     = var.eso_ksa_namespace
  ksa_name          = var.eso_ksa_name
  project_iam_roles = ["roles/secretmanager.secretAccessor"]
}

# CNPG -> GCS backup bucket Workload Identity binding
module "gcp_cnpg_backup_identity" {
  source = "../../modules/gcp-workload-identity"

  project_id       = var.gcp_project_id
  gsa_account_id   = "cnpg-backup-writer"
  gsa_display_name = "CNPG - GCS backup writer"
  ksa_namespace    = var.cnpg_ksa_namespace
  ksa_name         = var.cnpg_ksa_name

  bucket_iam_bindings = [
    {
      bucket_name = module.gcp_cnpg_backup_bucket.bucket_name
      role        = "roles/storage.objectAdmin"
    }
  ]
}
