variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "uami_name" {
  type = string
}

variable "aks_oidc_issuer_url" {
  description = "From module.aks.oidc_issuer_url"
  type        = string
}

variable "ksa_namespace" {
  type = string
}

variable "ksa_name" {
  description = "Must exactly match the KSA that carries the azure.workload.identity/client-id annotation"
  type        = string
}

variable "role_assignments" {
  type = list(object({
    scope                 = string
    role_definition_name  = string
  }))
  default = []
}
