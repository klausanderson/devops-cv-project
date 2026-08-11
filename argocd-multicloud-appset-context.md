# ArgoCD multi-cloud migration — context for Claude Code

Generated from a planning conversation. This is a briefing document, not a diff —
none of the files below exist yet except where noted. Use it as the spec for
implementing the GKE+AKS ApplicationSet migration in `klausanders444/devops-cv-project`.

## 1. Background

- ArgoCD runs on GKE and currently only manages itself: a flat `argocd/apps/*.yaml`
  directory of ~13 `Application` CRDs, all implicitly targeting
  `destination.server: https://kubernetes.default.svc`.
- Goal: extend the same stack to AKS, registered as a second, remote cluster, without
  hand-maintaining a duplicate Application file per cloud.
- ESO and CNPG are **not** cloud-agnostic — their manifests use different provider
  syntax (`gcpsm` vs `azurekv`, `googleCloudStorage` vs `azureCredentials`) and
  different workload identity mechanisms. These cannot be deployed from a single
  shared manifest; they need cloud-specific source paths.
- Decision made during planning: use **ApplicationSet** (matrix generator: app list ×
  cluster list) instead of hand-written per-cluster `Application` files. This reduces
  the file count from ~28 (13 apps × 2 clouds, explicit) to 4-5 generator files.
- Section `04-eso-and-cnpg-and-tilt/` has **already been split** into `manifests/gcp/`
  and `manifests/azure/` subfolders per affected component (see §5). This is a
  precondition the ApplicationSet design assumes.

## 2. Cluster registration

### AKS (remote cluster)

Avoid `az aks get-credentials` + default `argocd cluster add`, which produces an
exec-based (`kubelogin`) kubeconfig — the ArgoCD application-controller pod does not
have `az`/`kubelogin` installed and sync will fail. Use a token-based ServiceAccount
instead:

```bash
kubectl --context aks-cluster create namespace argocd-manager
kubectl --context aks-cluster create serviceaccount argocd-manager -n argocd-manager
kubectl --context aks-cluster create clusterrolebinding argocd-manager \
  --clusterrole=cluster-admin --serviceaccount=argocd-manager:argocd-manager
```

k8s 1.24+ doesn't auto-generate SA token secrets — create one explicitly:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: argocd-manager
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
```

Build a token-based kubeconfig (no `exec:` block) from that secret's token + CA +
AKS API server URL, then register with the `cloud` label applied at registration time
(needed by the ApplicationSet `clusters` generator, see §7):

```bash
argocd cluster add aks-token-context \
  --name aks-cluster \
  --label cloud=azure \
  --kubeconfig ./aks-token-kubeconfig.yaml
```

If the ArgoCD CLI version predates `--label`, register first, then find and patch:

```bash
kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster
kubectl -n argocd label secret cluster-<derived-name> cloud=azure
```

Verify:

```bash
kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type=cluster \
  -o custom-columns=NAME:.metadata.name,CLOUD:.metadata.labels.cloud
```

### GKE (hub)

ArgoCD's `in-cluster` entry is synthetic — no `Secret` exists for it by default, so
the `clusters` generator's label selector has nothing to match. Create a real,
credential-free secret (safe to commit) at `argocd/clusters/gke-hub.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gke-hub
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    cloud: gcp
type: Opaque
stringData:
  name: gke-hub
  server: https://kubernetes.default.svc
  config: '{"tlsClientConfig":{"insecure":false}}'
```

To avoid ArgoCD listing both this and the built-in synthetic in-cluster entry for the
same API server, disable the implicit one in `argocd/argocd-values.yaml`:

```yaml
configs:
  cm:
    cluster.inClusterEnabled: "false"
```

## 3. Workload identity — already scripted, reference only

These commands were reviewed during planning and should already exist somewhere in
the Terraform/bootstrap flow. Included here as the authorization chain the
ApplicationSet-deployed `ClusterSecretStore`/CNPG resources depend on.

**Azure — trust binding (KSA → managed identity):**

```bash
az identity federated-credential create \
  --name external-secrets \
  --identity-name external-secrets \
  --resource-group k8s-learning-rg \
  --issuer "$(az aks show --name k8s-learning-aks --resource-group k8s-learning-rg \
              --query oidcIssuerProfile.issuerUrl -o tsv)" \
  --subject "system:serviceaccount:external-secrets:external-secrets" \
  --audience api://AzureADTokenExchange
```

**Azure — authorization (what the identity can access):**

```bash
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee "$(az identity show --name external-secrets \
                --resource-group k8s-learning-rg --query principalId -o tsv)" \
  --scope "$(az keyvault show --name k8s-learning-kv --query id -o tsv)"
```

Only works if the vault uses the RBAC authorization model, not legacy access
policies — verify with:
`az keyvault show --name k8s-learning-kv --query properties.enableRbacAuthorization`

**GCP — trust binding (KSA → GSA impersonation):**

```bash
gcloud iam service-accounts add-iam-policy-binding \
  external-secrets@k8s-learning-gke.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:k8s-learning-gke.svc.id.goog[external-secrets/external-secrets]"
```

**⚠ OPEN GAP — GCP authorization step is missing.** Unlike Azure, this binding only
covers KSA↔GSA trust, not Secret Manager access. There should be a companion command
granting `roles/secretmanager.secretAccessor` to the GSA, equivalent to the Azure role
assignment above. Confirm whether this exists in the Terraform `gcp-workload-identity`
module; if not, it needs to be added before ESO can read secrets on GKE.

```bash
# Expected but unconfirmed — verify/add:
gcloud secrets add-iam-policy-binding <secret-name> \
  --role roles/secretmanager.secretAccessor \
  --member "serviceAccount:external-secrets@k8s-learning-gke.iam.gserviceaccount.com"
```

## 4. ESO / CNPG cloud-specific manifest reference

**ESO `ClusterSecretStore`:**

```yaml
# manifests/gcp/ClusterSecretStore.yaml
spec:
  provider:
    gcpsm:
      projectID: <project-id>
      auth:
        workloadIdentity:
          clusterLocation: <region>
          clusterName: <gke-cluster-name>
          serviceAccountRef:
            name: eso-gcp-ksa
            namespace: external-secrets
```

```yaml
# manifests/azure/ClusterSecretStore.yaml
spec:
  provider:
    azurekv:
      vaultUrl: "https://<vault-name>.vault.azure.net"
      authType: WorkloadIdentity
      serviceAccountRef:
        name: eso-azure-ksa
        namespace: external-secrets
```

**ServiceAccount identity binding:**

```yaml
# gcp: GKE metadata-server interception via annotation
metadata:
  annotations:
    iam.gke.io/gcp-service-account: eso-sa@<project-id>.iam.gserviceaccount.com
```

```yaml
# azure: mutating webhook injects projected token; needs BOTH annotation and label
metadata:
  annotations:
    azure.workload.identity/client-id: <managed-identity-client-id>
  labels:
    azure.workload.identity/use: "true"
```

**CNPG backup target:**

```yaml
# gcp
backup:
  barmanObjectStore:
    destinationPath: "gs://<bucket>/cnpg-backups"
    googleCloudStorage: {}
```

```yaml
# azure — CNPG pods also need serviceAccountTemplate annotations mirroring the SA above
backup:
  barmanObjectStore:
    destinationPath: "https://<storageaccount>.blob.core.windows.net/cnpg-backups"
    azureCredentials:
      inheritFromAzureAD: true
```

## 5. Current section-04 tree (already split, precondition for §7)

```
04-eso-and-cnpg-and-tilt/
├── cloudnative-pg/
│   ├── Taskfile.yaml              # must stay ABOVE manifests/ — not a valid k8s resource
│   └── manifests/
│       ├── gcp/    Namespace.yaml, Cluster.yaml, Backup.yaml, ScheduleBackup.yaml
│       └── azure/  Namespace.yaml, Cluster.yaml, Backup.yaml, ScheduleBackup.yaml
├── external-secrets-operator/
│   ├── Taskfile.yaml
│   ├── values-gcp.yaml            # Helm chart values — NOT under manifests/
│   ├── values-azure.yaml
│   └── manifests/
│       ├── gcp/    ClusterSecretStore.yaml, ExternalSecret.yaml, ServiceAccount.yaml
│       └── azure/  ClusterSecretStore.yaml, ExternalSecret.yaml, ServiceAccount.yaml
├── cnpg-demo-app-access/
│   ├── Taskfile.yaml
│   └── manifests/{gcp,azure}/
└── kube-prometheus-stack/
    ├── Taskfile.yaml
    ├── values-gcp.yaml
    ├── values-azure.yaml
    └── manifests/{gcp,azure}/    ExternalSecret-grafana-admin.yaml, Namespace.yaml
```

`Namespace.yaml` is byte-identical between `gcp/` and `azure/` in each component —
duplicated for now since directory-type Applications can't merge two paths. A
Kustomize `base/` + `overlays/{gcp,azure}/` restructure is a reasonable follow-up for
`cloudnative-pg` specifically (its `Cluster.yaml` is ~90% shared), but not worth it for
`external-secrets-operator`, where the `ClusterSecretStore` provider blocks share
almost nothing. Not required for this migration — noted for later.

## 6. Target `argocd/` folder structure

```diff
 argocd/
   ├── Taskfile.yaml
   ├── argocd-values.yaml
   ├── root-app.yaml
-  └── apps/
-      ├── api-golang.yaml
-      ├── api-node.yaml
-      ├── argocd-ingress.yaml
-      ├── cert-manager-issuers.yaml
-      ├── client-react.yaml
-      ├── cnpg-demo-app-access.yaml
-      ├── cnpg.yaml
-      ├── eso.yaml
-      ├── grafana-dashboards.yaml
-      ├── grafana-ingress.yaml
-      ├── kube-prometheus-stack.yaml
-      ├── load-generator-python.yaml
-      └── middleware.yaml
+  ├── applicationsets/
+  │   ├── shared-apps.yaml
+  │   ├── cloud-specific-manifests.yaml
+  │   ├── cloud-specific-charts.yaml
+  │   └── hub-only-apps.yaml
+  └── clusters/
+      └── gke-hub.yaml
```

`root-app.yaml` now points at `argocd/applicationsets` (directory, no recurse) instead
of `argocd/apps`, so it manages the ApplicationSet *definitions*, which in turn
generate all downstream `Application` objects.

```yaml
# argocd/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/klausanders444/devops-cv-project.git
    targetRevision: main
    path: argocd/applicationsets
    directory:
      recurse: false
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

## 7. App classification

Apps split three ways based on **how** the cloud difference is expressed, not just
whether one exists:

| File | Cloud difference lives in | Apps |
|---|---|---|
| `shared-apps.yaml` | nothing — destination only | api-golang, api-node, client-react, middleware, cert-manager-issuers, grafana-dashboards, load-generator-python |
| `cloud-specific-manifests.yaml` | `source.path` | cnpg, cnpg-demo-app-access, eso-config, kps-config |
| `cloud-specific-charts.yaml` | `helm.valueFiles` | eso (chart install), kube-prometheus-stack (chart install) |
| `hub-only-apps.yaml` | N/A — no cluster fan-out | argocd-ingress |

Notes:

- `eso` and `kube-prometheus-stack` are upstream Helm charts, not directory manifests
  from this repo — splitting `manifests/gcp|azure` doesn't affect them. What differs
  per cloud is the **values file**, so they need a multi-source Application with a
  `ref` source for values resolution, not a templated `path`.
- `eso` (chart) and `eso-config` (the `ClusterSecretStore`/`ExternalSecret`/
  `ServiceAccount` CRs) are deliberately separate apps at different sync waves — the
  CRs depend on ESO's CRDs existing first. Same split for `kube-prometheus-stack` /
  `kps-config`.
- `kube-prometheus-stack` and `cnpg-demo-app-access` belong in the cloud-specific set
  even though neither is an identity component itself — both contain
  `ExternalSecret`s whose `secretStoreRef` points at a cloud-specific
  `ClusterSecretStore`.
- `argocd-ingress` must NOT be in a cluster-fanned-out set — ArgoCD only runs on the
  GKE hub, so fanning it out would generate a `Certificate`/`IngressRoute` pair for a
  service that doesn't exist on AKS.
- **`grafana-ingress` is deliberately excluded from all sets below** — see §9.

## 8. ApplicationSet manifests

### `argocd/applicationsets/shared-apps.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: shared-apps
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - app: api-golang
                  path: 03-Project-manifests/api-golang
                  namespace: api-golang
                  syncWave: "5"
                - app: api-node
                  path: 03-Project-manifests/api-node
                  namespace: api-node
                  syncWave: "5"
                - app: client-react
                  path: 03-Project-manifests/client-react
                  namespace: client-react
                  syncWave: "5"
                - app: middleware
                  path: 03-Project-manifests/common/manifests
                  namespace: traefik
                  syncWave: "0"
                - app: cert-manager-issuers
                  path: 03-Project-manifests/cert-manager-issuers/manifests
                  namespace: cert-manager
                  syncWave: "1"
                - app: grafana-dashboards
                  path: 03-Project-manifests/grafana-dashboards
                  namespace: monitoring
                  syncWave: "4"
                - app: load-generator-python
                  path: 03-Project-manifests/load-generator-python
                  namespace: load-generator
                  syncWave: "6"
          - clusters:
              selector:
                matchLabels:
                  argocd.argoproj.io/secret-type: cluster
  template:
    metadata:
      name: '{{.app}}-{{.nameNormalized}}'
      annotations:
        argocd.argoproj.io/sync-wave: '{{.syncWave}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/klausanders444/devops-cv-project.git
        targetRevision: main
        path: '{{.path}}'
      destination:
        name: '{{.name}}'
        namespace: '{{.namespace}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions:
          - CreateNamespace=true
```

Use `.nameNormalized` (strips k8s-illegal characters) in the Application *name*, but
plain `.name` in `destination.name`, which must exactly match the registered cluster
name from §2.

### `argocd/applicationsets/cloud-specific-manifests.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cloud-specific-manifests
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - app: cnpg
                  basePath: 04-eso-and-cnpg-and-tilt/cloudnative-pg/manifests
                  namespace: cnpg-system
                  syncWave: "2"
                - app: cnpg-demo-app-access
                  basePath: 04-eso-and-cnpg-and-tilt/cnpg-demo-app-access/manifests
                  namespace: cnpg-demo
                  syncWave: "3"
                - app: eso-config
                  basePath: 04-eso-and-cnpg-and-tilt/external-secrets-operator/manifests
                  namespace: external-secrets
                  syncWave: "2"
                - app: kps-config
                  basePath: 04-eso-and-cnpg-and-tilt/kube-prometheus-stack/manifests
                  namespace: monitoring
                  syncWave: "4"
          - clusters:
              selector:
                matchLabels:
                  argocd.argoproj.io/secret-type: cluster
  template:
    metadata:
      name: '{{.app}}-{{.nameNormalized}}'
      annotations:
        argocd.argoproj.io/sync-wave: '{{.syncWave}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/klausanders444/devops-cv-project.git
        targetRevision: main
        path: '{{.basePath}}/{{.metadata.labels.cloud}}'
      destination:
        name: '{{.name}}'
        namespace: '{{.namespace}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
```

`{{.metadata.labels.cloud}}` combined with `missingkey=error` (direct field access,
not `index`) means a missing `cloud` label on a cluster secret fails the
ApplicationSet loudly instead of silently under-generating. Check with:
`kubectl -n argocd get applicationset cloud-specific-manifests -o jsonpath='{.status.conditions}'`

`ServerSideApply=true` is scoped to this set (needed for kube-prometheus-stack CRDs
exceeding the client-side apply annotation limit — documented incident) rather than
applied blanket to `shared-apps`.

**Never** let `basePath` resolve to the parent directory with `directory.recurse: true`
— that would apply both clouds' manifests to whichever cluster syncs first. The
template always appends `/{{.metadata.labels.cloud}}`, so this is safe as long as no
one hand-writes an Application that omits it.

### `argocd/applicationsets/cloud-specific-charts.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cloud-specific-charts
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - app: eso
                  chart: external-secrets
                  chartRepo: https://charts.external-secrets.io
                  chartVersion: 0.10.4
                  valuesPath: 04-eso-and-cnpg-and-tilt/external-secrets-operator
                  namespace: external-secrets
                  syncWave: "1"
                - app: kube-prometheus-stack
                  chart: kube-prometheus-stack
                  chartRepo: https://prometheus-community.github.io/helm-charts
                  chartVersion: 65.5.1
                  valuesPath: 04-eso-and-cnpg-and-tilt/kube-prometheus-stack
                  namespace: monitoring
                  syncWave: "3"
          - clusters:
              selector:
                matchLabels:
                  argocd.argoproj.io/secret-type: cluster
  template:
    metadata:
      name: '{{.app}}-{{.nameNormalized}}'
      annotations:
        argocd.argoproj.io/sync-wave: '{{.syncWave}}'
    spec:
      project: default
      sources:
        - repoURL: '{{.chartRepo}}'
          chart: '{{.chart}}'
          targetRevision: '{{.chartVersion}}'
          helm:
            valueFiles:
              - $vals/{{.valuesPath}}/values-{{.metadata.labels.cloud}}.yaml
        - repoURL: https://github.com/klausanders444/devops-cv-project.git
          targetRevision: main
          ref: vals
      destination:
        name: '{{.name}}'
        namespace: '{{.namespace}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions:
          - CreateNamespace=true
```

Confirm actual chart versions currently pinned in the existing Helm-based
`argocd/apps/eso.yaml` / `kube-prometheus-stack.yaml` before replacing them — the
versions above are placeholders from planning, not verified against the repo.

### `argocd/applicationsets/hub-only-apps.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: hub-only-apps
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - app: argocd-ingress
            path: 03-Project-manifests/argocd-ingress
            namespace: argocd
            cluster: gke-hub
  template:
    metadata:
      name: '{{.app}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/klausanders444/devops-cv-project.git
        targetRevision: main
        path: '{{.path}}'
      destination:
        name: '{{.cluster}}'
        namespace: '{{.namespace}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
```

## 9. Open items / not yet resolved

1. **GCP secretAccessor role binding** — confirm or add (§3). Without it, ESO on GKE
   will authenticate fine but 403 on every secret read.
2. **`grafana-ingress` fan-out conflict** — each cluster runs its own Grafana, but a
   naive fan-out would give both clusters the same hostname/`IngressRoute`, causing
   two Let's Encrypt HTTP-01 challenges to race for one DNS record. Needs per-cluster
   hostname values (Helm value or Kustomize overlay with cluster name templated in)
   before it can join `shared-apps`. Not included in any ApplicationSet above —
   handle as a follow-up, not part of this migration.
3. **Kustomize base/overlay for `cloudnative-pg`** — optional cleanup to de-duplicate
   the ~90%-identical `Cluster.yaml` between clouds. Not required for the migration to
   function; `external-secrets-operator` should stay as flat gcp/azure folders since
   its manifests don't share meaningfully.
4. **AppProject scoping** — not implemented. Optionally create `gcp`/`azure`
   AppProjects with `destinations` restricted per cluster, so a bad label or template
   bug can't sync an Azure-flavored resource onto GKE. Worth adding once the base
   migration is verified working.
5. **Verify Helm chart versions** in `cloud-specific-charts.yaml` against what's
   currently pinned in the pre-migration `argocd/apps/eso.yaml` and
   `kube-prometheus-stack.yaml` — placeholders above, not confirmed.

## 10. Implementation checklist for Claude Code

- [ ] Confirm/add GCP `secretAccessor` role binding (§3 gap)
- [ ] Create `argocd/clusters/gke-hub.yaml`, disable `cluster.inClusterEnabled` in
      `argocd-values.yaml`
- [ ] Register AKS cluster with token-based kubeconfig + `cloud=azure` label (§2)
- [ ] Create `argocd/applicationsets/shared-apps.yaml`
- [ ] Create `argocd/applicationsets/cloud-specific-manifests.yaml`
- [ ] Create `argocd/applicationsets/cloud-specific-charts.yaml` (verify chart
      versions first)
- [ ] Create `argocd/applicationsets/hub-only-apps.yaml`
- [ ] Update `argocd/root-app.yaml` to point at `argocd/applicationsets`
- [ ] Delete `argocd/apps/*.yaml` (13 files) and `argocd/root-apps/` if it exists from
      an earlier iteration
- [ ] Verify generated Applications: `kubectl -n argocd get applications` should show
      one entry per app×cluster combination per §7's table
- [ ] Check both ApplicationSets' `status.conditions` for template errors
      (`missingkey=error` will surface a missing `cloud` label loudly)
- [ ] Leave `grafana-ingress` out of scope for this pass (§9.2)
