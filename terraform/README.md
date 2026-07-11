# Terraform - Cluster Provisioning (GKE + AKS)

Replaces the imperative `azure:*` / `gcp:*` cluster-creation tasks in the
Taskfile with Terraform. `kind:*` tasks are untouched — a local KinD cluster
has no cloud resources to manage with Terraform.

## What this does that the Taskfile didn't

Beyond a straight lift of the `create-VNET` / `create-subnet` / `create-cluster`
commands, this also provisions the pieces those tasks implicitly assumed
existed already:

- **GCS bucket + Azure Blob container** for CNPG backups
- **GSA↔KSA Workload Identity binding (GCP)** and **UAMI federated credential
  (Azure)** for both ESO and CNPG, so neither operator needs a static key

## Folder structure

```
terraform/
├── README.md
├── .gitignore
├── bootstrap/                     # run once, by hand, before anything else
│   ├── main.tf                    # creates the GCS bucket that holds
│   ├── variables.tf                # environments/dev's remote state
│   └── terraform.tfvars.example
├── environments/
│   └── dev/
│       ├── backend.tf              # gcs backend -> bootstrap's bucket
│       ├── providers.tf            # google + azurerm provider config
│       ├── variables.tf            # every input, with defaults matching
│       │                           # your current Taskfile values
│       ├── gcp.tf                  # instantiates the gcp-* modules
│       ├── azure.tf                # instantiates the azure-* modules
│       ├── outputs.tf
│       ├── terraform.tfvars.example
│       └── .gitignore
└── modules/
    ├── gcp-network/                # VPC + subnet   (gcp:04, gcp:05)
    ├── gcp-gke/                    # cluster + node pool   (gcp:06)
    ├── gcp-storage/                # GCS bucket for CNPG backups
    ├── gcp-workload-identity/      # generic GSA + WI binding, used twice
    ├── azure-network/              # resource group + VNet + subnet (azure:03-06)
    ├── azure-aks/                  # cluster   (azure:07)
    ├── azure-storage/              # storage account + container
    └── azure-workload-identity/    # generic UAMI + federated credential, used twice
```

If you want this to slot into your existing numbered folder convention
(`02-Source-Code-and-Dockerfiles/`, `03-Project-manifests/`, ...), rename
the top-level `terraform/` directory to `01-Terraform/` — it makes sense as
the first step, since everything else deploys on top of these clusters.

## Taskfile task → Terraform mapping

| Taskfile task | Terraform equivalent |
|---|---|
| `gcp:01-init-cli` | not automated — one-time `gcloud init` auth, stays manual |
| `gcp:02-enable-apis` | `google_project_service.apis` in `gcp.tf` |
| `gcp:03-set-region-and-zone` | not needed — provider block sets region explicitly |
| `gcp:04-create-vpc` | `module.gcp_network` (`gcp-network`) |
| `gcp:05-create-subnet` | `module.gcp_network` (`gcp-network`) |
| `gcp:06-create-cluster` | `module.gke` (`gcp-gke`) |
| `azure:01-init-azure-cli` | not automated — one-time `az login`, stays manual |
| `azure:02-giving-permissions-to-create` | not automated — subscription-level provider registration, typically one-time; use `az provider register` or `azurerm_resource_provider_registration` if you want it in Terraform too |
| `azure:03-create-resource-group` | `module.azure_network` (`azure-network`) |
| `azure:04-configure-defaults-location` | not needed — every resource sets location explicitly |
| `azure:05-create-VNET` | `module.azure_network` (`azure-network`) |
| `azure:06-create-subnet` | `module.azure_network` (`azure-network`) |
| `azure:07-create-cluster` | `module.aks` (`azure-aks`) |
| *(new)* | `module.gcp_cnpg_backup_bucket`, `module.azure_cnpg_backup_storage` |
| *(new)* | `module.gcp_eso_identity`, `module.gcp_cnpg_backup_identity` |
| *(new)* | `module.azure_eso_identity`, `module.azure_cnpg_backup_identity` |

`gcp:08/09` and `azure:08/09` (connect / clean-up) are covered by the
`get_credentials_command` outputs and plain `terraform destroy` respectively.

## Order of operations

```bash
# 1. One-time: create the remote state bucket
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # fill in your project ID
terraform init
terraform apply

# 2. Provision both clusters + supporting infra
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars   # fill in subscription ID, Key Vault ID, etc.
terraform init
terraform plan
terraform apply
```

Given your existing principle that local `terraform apply` is an
anti-pattern outside learning environments — this `apply` step is exactly
the kind of thing to eventually move into `05-cicd-github-actions/` as a
separate Terraform-plan/apply workflow, with `TF_VAR_azure_subscription_id`
etc. injected as CI secrets rather than sitting in a local `.tfvars`.

## Things that need your input before `apply` works

1. **`azure_key_vault_id`** (required, no default) — this config assumes
   your Azure Key Vault already exists from earlier ESO setup. Paste its
   resource ID into `terraform.tfvars`. If you'd rather have Terraform
   create it too, replace the variable's single use in `azure.tf` with a
   real `azurerm_key_vault` resource — happy to add that module if useful.
2. **`azure_storage_account_name`** and **`cnpg_backup_bucket_name`** must
   be globally unique (Azure Storage Accounts and GCS buckets both share a
   single global namespace). The example names will very likely collide
   with someone else's — change them.
3. **`cnpg_ksa_name` / `cnpg_ksa_namespace` defaults** (`cnpg-backup` /
   `db`) are a guess — double-check them against whatever
   `serviceAccountTemplate.metadata.name` your CNPG `Cluster` resource
   actually uses in `04-eso-and-cnpg-and-tilt/`, and adjust the variable if
   they don't match. A mismatch here means the Workload Identity binding
   points at a KSA that doesn't exist, and CNPG backups silently fail auth
   instead of erroring loudly.

## Known provider gap: AKS Gateway API

The `azurerm` provider doesn't yet expose AKS's managed Gateway API add-on
as a native resource attribute — it's an [open upstream
issue](https://github.com/hashicorp/terraform-provider-azurerm/issues/31710).
`modules/azure-aks` works around this with a `null_resource` +
`local-exec` calling `az aks update --enable-gateway-api`, which means
`terraform apply` needs an authenticated `az` CLI on whatever machine (or
CI runner) runs it. Set `enable_gateway_api = false` in `azure.tf` if you'd
rather apply that step manually and keep local-exec out of your state.

## Wiring the outputs into ESO / your ArgoCD manifests

After `terraform apply`, the annotations your Kubernetes ServiceAccounts
need come straight out of the outputs:

```bash
# GCP: iam.gke.io/gcp-service-account annotation on the ESO KSA
terraform output gcp_eso_gsa_email

# GCP: same, for the CNPG KSA
terraform output gcp_cnpg_gsa_email

# Azure: azure.workload.identity/client-id annotation on the ESO KSA
terraform output azure_eso_uami_client_id

# Azure: same, for the CNPG KSA
terraform output azure_cnpg_uami_client_id

# Azure: needed to fill in the AKS ClusterSecretStore's provider block
terraform output aks_oidc_issuer_url
```

These map onto the ClusterSecretStore / ExternalSecret manifests already
living in `04-eso-and-cnpg-and-tilt/` — no changes needed there beyond
making sure the annotation values match what Terraform just created.
