# Generic UAMI <-> KSA federated identity module. Instantiated twice from
# environments/dev/azure.tf: once for ESO (Key Vault access) and once for
# CNPG (Blob Storage access) - mirrors the gcp-workload-identity module,
# but Azure requires the federated credential to be created explicitly
# (GKE derives its equivalent automatically).

resource "azurerm_user_assigned_identity" "this" {
  name                = var.uami_name
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "this" {
  for_each = { for r in var.role_assignments : "${r.scope}-${r.role_definition_name}" => r }

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id          = azurerm_user_assigned_identity.this.principal_id
}

# The subject here MUST byte-for-byte match the Kubernetes ServiceAccount's
# namespace and name - this is the single most common source of "identity
# not found" errors when wiring up ESO/CNPG workload identity on AKS.
resource "azurerm_federated_identity_credential" "this" {
  name                = "${var.uami_name}-fic"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:${var.ksa_namespace}:${var.ksa_name}"
}
