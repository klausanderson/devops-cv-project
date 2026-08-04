# Terraform - Cluster Provisioning (GKE + AKS)

Replaces the `gcp:*` / `azure:*` cluster-creation tasks in the
Taskfile with Terraform.

## What each cloud gets (identical shape, per-cloud mechanics)

| Concern | GCP | Azure |
|---|---|---|---|
| Network | VPC + 1 subnet | RG + VNet + 1 subnet | 
| Cluster | GKE zonal, 2× e2-standard-2 | AKS, 2× Standard_D2s_v3 |
| Cluster identity | implicit | `SystemAssigned` managed identity |
| Backup storage | GCS bucket | Storage Account + container |
| Workload identity | GSA + WI binding | UAMI + federated credential |
| WI extra plumbing | none | enable OIDC issuer |

## Folder structure

```
terraform/
├── README.md
├── .gitignore
├── bootstrap/                      # run once, by hand - creates the GCS
│   ├── main.tf                     # bucket that holds environments/dev's
│   ├── variables.tf                # remote state
│   └── terraform.tfvars.example
├── environments/
│   └── dev/
│       ├── backend.tf              # gcs backend -> bootstrap's bucket
│       ├── providers.tf            # google + azurerm
│       ├── variables.tf            # all inputs, defaults match the Taskfile
│       ├── gcp.tf                  # instantiates the gcp-* modules
│       ├── azure.tf                # instantiates the azure-* modules
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── modules/
    ├── gcp-network/                # VPC + subnet          (gcp:04, gcp:05)
    ├── gcp-gke/                    # cluster + node pool   (gcp:06)
    ├── gcp-storage/                # GCS bucket for CNPG backups
    ├── gcp-workload-identity/      # generic GSA + WI binding, used 2x
    ├── azure-network/              # RG + VNet + subnet    (azure:03-06)
    ├── azure-aks/                  # cluster               (azure:07)
    ├── azure-storage/              # storage account + container
    └── azure-workload-identity/    # generic UAMI + federated cred, used 2x
```

## Taskfile task → Terraform mapping

| Taskfile task | Terraform equivalent |
|---|---|
| `gcp:01-init-cli` | not automated — one-time `gcloud init`, stays manual |
| `gcp:02-enable-apis` | `google_project_service.apis` in `gcp.tf` |
| `gcp:03-set-region-and-zone` | not needed — provider block sets region |
| `gcp:04/05-create-vpc/subnet` | `module.gcp_network` |
| `gcp:06-create-cluster` | `module.gke` |
| `azure:01-init-azure-cli` | not automated — one-time `az login`, stays manual |
| `azure:02-giving-permissions` | not automated — one-time provider registration |
| `azure:03-create-resource-group` | `module.azure_network` (`azurerm_resource_group`) |
| `azure:04-configure-defaults` | not needed — every resource sets location explicitly |
| `azure:05/06-create-VNET/subnet` | `module.azure_network` |
| `azure:07-create-cluster` | `module.aks` |
| `azure:08-connect` / `gcp:08` | `*_get_credentials_command` outputs |
| `azure:09` / `gcp:09-clean-up` | `terraform destroy` |
| `azure:10-query-for-nodepools` | `az aks nodepool list ...` — read-only query, stays CLI |
| *(new)* | module.gcp_cnpg_backup_bucket, module.azure_cnpg_backup_storage |
| *(new)* | module.gcp_eso_identity, module.gcp_cnpg_backup_identity |
| *(new)* | module.azure_eso_identity, module.azure_cnpg_backup_identity |

## Order of operations

```bash
# 0. One-time CLI auth per cloud (the Terraform providers piggyback on these)
gcloud auth application-default login    # distinct from plain gcloud auth!
az login


# 1. One-time: create the remote state bucket
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply

# 2. Provision all three clusters + supporting infra
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Things that need your input before `apply` works

1. **`azure_key_vault_id`** (required, no default) — resource ID of the
   existing Key Vault from earlier ESO setup.
2. **Globally-unique names** — `azure_storage_account_name`,
   `cnpg_backup_bucket_name`, `cnpg_backup_s3_bucket_name`. GCS, Azure
   Storage, and S3 all share global namespaces.
3. **`cnpg_ksa_name`/`cnpg_ksa_namespace` defaults** are a guess — verify
   against the CNPG `Cluster` `serviceAccountTemplate` in
   `04-eso-and-cnpg-and-tilt/`.


## Wiring the outputs into ESO / your ArgoCD manifests

```bash
# GCP: iam.gke.io/gcp-service-account annotation values
terraform output gcp_eso_gsa_email
terraform output gcp_cnpg_gsa_email

# Azure: azure.workload.identity/client-id annotation values
terraform output azure_eso_uami_client_id
terraform output azure_cnpg_uami_client_id
terraform output aks_oidc_issuer_url

