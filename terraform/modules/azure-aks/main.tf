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

# The azurerm provider does not (yet) expose AKS's managed Gateway API
# add-on as a native attribute on azurerm_kubernetes_cluster - it's tracked
# upstream (hashicorp/terraform-provider-azurerm#31710) and still open.
# Until it lands, this replicates `az aks create --enable-gateway-api` via
# az CLI local-exec so the module output still matches the old Taskfile
# behavior. Requires the Azure CLI to be authenticated wherever `terraform
# apply` runs (e.g. in your CI runner).
resource "null_resource" "enable_gateway_api" {
  count = var.enable_gateway_api ? 1 : 0

  triggers = {
    cluster_id = azurerm_kubernetes_cluster.this.id
  }

  provisioner "local-exec" {
    command = "az aks update --resource-group ${var.resource_group_name} --name ${var.cluster_name} --enable-gateway-api"
  }
}
