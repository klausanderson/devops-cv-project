# Azure Blob Storage equivalent of the GCS bucket used for CNPG backups -
# this is what CNPG on AKS writes Barman/WAL backups to.
resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_name = azurerm_storage_account.this.name
  container_access_type = "private"
}
