output "client_id" {
  description = "Set this as the azure.workload.identity/client-id annotation on the KSA"
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  value = azurerm_user_assigned_identity.this.principal_id
}

output "uami_id" {
  value = azurerm_user_assigned_identity.this.id
}
