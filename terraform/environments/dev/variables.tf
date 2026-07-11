# ---------------------------------------------------------------------------
# GCP - general
# ---------------------------------------------------------------------------
variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "europe-central2"
}

variable "gcp_zone" {
  type    = string
  default = "europe-central2-a"
}

variable "gcp_apis" {
  description = "APIs to enable on the project (replaces the Taskfile's gcp:02-enable-apis task)"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "servicemanagement.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ---------------------------------------------------------------------------
# GCP - network + GKE
# ---------------------------------------------------------------------------
variable "gcp_network_name" {
  type    = string
  default = "klaus-learning"
}

variable "gcp_subnet_cidr" {
  type    = string
  default = "10.0.0.0/20"
}

variable "gke_cluster_name" {
  type    = string
  default = "gke-klaus-learning"
}

variable "gke_machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "gke_disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "gke_disk_size_gb" {
  type    = number
  default = 50
}

variable "gke_node_count" {
  type    = number
  default = 2
}

# ---------------------------------------------------------------------------
# GCP - CNPG backup bucket
# ---------------------------------------------------------------------------
variable "cnpg_backup_bucket_name" {
  description = "Must be globally unique across all of GCS"
  type        = string
  default     = "klaus-devops-journey-cnpg-backups"
}

variable "cnpg_backup_retention_days" {
  type    = number
  default = 30
}

# ---------------------------------------------------------------------------
# Kubernetes namespaces/ServiceAccounts that ESO and CNPG actually run as -
# these MUST match what's deployed in-cluster (Helm values / CNPG Cluster
# serviceAccountTemplate) or the Workload Identity bindings are pointless.
# ---------------------------------------------------------------------------
variable "eso_ksa_namespace" {
  type    = string
  default = "external-secrets"
}

variable "eso_ksa_name" {
  type    = string
  default = "external-secrets"
}

variable "cnpg_ksa_namespace" {
  description = "Matches the ESO ClusterSecretStore remoteNamespace convention already in use (db)"
  type        = string
  default     = "db"
}

variable "cnpg_ksa_name" {
  type    = string
  default = "cnpg-backup"
}

# ---------------------------------------------------------------------------
# Azure - general
# ---------------------------------------------------------------------------
variable "azure_subscription_id" {
  type = string
}

variable "azure_resource_group" {
  type    = string
  default = "azure-devops-learning"
}

variable "azure_location" {
  type    = string
  default = "polandcentral"
}

# ---------------------------------------------------------------------------
# Azure - network + AKS
# ---------------------------------------------------------------------------
variable "aks_cluster_name" {
  type    = string
  default = "klaus-learning"
}

variable "azure_vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azure_subnet_cidr" {
  type    = string
  default = "10.0.0.0/20"
}

variable "azure_service_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "azure_dns_service_ip" {
  type    = string
  default = "10.1.0.10"
}

variable "aks_node_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "aks_node_os_disk_size_gb" {
  type    = number
  default = 50
}

variable "aks_node_count" {
  type    = number
  default = 2
}

# ---------------------------------------------------------------------------
# Azure - CNPG backup storage
# ---------------------------------------------------------------------------
variable "azure_storage_account_name" {
  description = "3-24 chars, lowercase letters/numbers only, globally unique across all of Azure"
  type        = string
  default     = "klausdevopscnpgbackup"
}

variable "cnpg_backup_container_name" {
  type    = string
  default = "cnpg-backups"
}

# ---------------------------------------------------------------------------
# Azure - Key Vault (ESO reads secrets from here). If you already have one
# from earlier ESO setup, either paste its resource ID below, or replace
# this variable's usage in azure.tf with a `data "azurerm_key_vault"` block
# pointed at the existing vault - don't let Terraform try to re-create it.
# ---------------------------------------------------------------------------
variable "azure_key_vault_id" {
  description = "Resource ID of the existing (or Terraform-managed) Azure Key Vault that ESO reads from"
  type        = string
}
