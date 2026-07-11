# Replaces azure:03 through azure:06 (resource group, VNet, subnet)
module "azure_network" {
  source = "../../modules/azure-network"

  resource_group_name   = var.azure_resource_group
  location               = var.azure_location
  vnet_name               = var.aks_cluster_name
  vnet_address_space     = var.azure_vnet_cidr
  subnet_address_prefix  = var.azure_subnet_cidr
}

# Replaces azure:07-create-cluster
module "aks" {
  source = "../../modules/azure-aks"

  resource_group_name  = module.azure_network.resource_group_name
  location              = module.azure_network.location
  cluster_name          = var.aks_cluster_name
  subnet_id             = module.azure_network.subnet_id
  service_cidr          = var.azure_service_cidr
  dns_service_ip        = var.azure_dns_service_ip
  node_vm_size           = var.aks_node_vm_size
  node_os_disk_size_gb   = var.aks_node_os_disk_size_gb
  node_count             = var.aks_node_count
  enable_gateway_api    = true
}

# CNPG backup storage (Azure Blob equivalent of the GCS bucket)
module "azure_cnpg_backup_storage" {
  source = "../../modules/azure-storage"

  resource_group_name    = module.azure_network.resource_group_name
  location                = module.azure_network.location
  storage_account_name  = var.azure_storage_account_name
  container_name          = var.cnpg_backup_container_name
}

# ESO -> Azure Key Vault federated identity
module "azure_eso_identity" {
  source = "../../modules/azure-workload-identity"

  resource_group_name  = module.azure_network.resource_group_name
  location              = module.azure_network.location
  uami_name             = "eso-keyvault-reader"
  aks_oidc_issuer_url  = module.aks.oidc_issuer_url
  ksa_namespace         = var.eso_ksa_namespace
  ksa_name              = var.eso_ksa_name

  role_assignments = [
    {
      scope                 = var.azure_key_vault_id
      role_definition_name  = "Key Vault Secrets User"
    }
  ]
}

# CNPG -> Azure Blob Storage federated identity
module "azure_cnpg_backup_identity" {
  source = "../../modules/azure-workload-identity"

  resource_group_name  = module.azure_network.resource_group_name
  location              = module.azure_network.location
  uami_name             = "cnpg-blob-writer"
  aks_oidc_issuer_url  = module.aks.oidc_issuer_url
  ksa_namespace         = var.cnpg_ksa_namespace
  ksa_name              = var.cnpg_ksa_name

  role_assignments = [
    {
      scope                 = module.azure_cnpg_backup_storage.storage_account_id
      role_definition_name  = "Storage Blob Data Contributor"
    }
  ]
}
