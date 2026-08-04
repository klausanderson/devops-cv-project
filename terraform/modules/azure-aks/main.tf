resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
  location             = var.location
  dns_prefix           = var.cluster_name

  # OIDC issuer + Workload Identity are the Azure equivalent of GKE's
  # workload_identity_config - together they let a Kubernetes ServiceAccount
  # be federated to an azurerm_user_assigned_identity (see the
  # azure-workload-identity module). Unlike GKE, the federated credential
  # subject has to be created explicitly and must byte-for-byte match
  # "system:serviceaccount:<namespace>:<ksa-name>".
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name            = "system"
    vm_size         = var.node_vm_size
    node_count      = var.node_count
    vnet_subnet_id  = var.subnet_id
    os_disk_type    = var.node_os_disk_type
    os_disk_size_gb = var.node_os_disk_size_gb
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  identity {
    type = "SystemAssigned"
  }
}
