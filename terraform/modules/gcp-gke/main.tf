# Mirrors `gcloud container clusters create` from the Taskfile, but splits
# the cluster control plane from the node pool. Terraform best practice is
# to NOT rely on the default node pool GKE creates implicitly (which is
# what --num-nodes 2 gave you imperatively) - we remove it immediately and
# manage a real, independently-scalable google_container_node_pool instead.
resource "google_container_cluster" "this" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_self_link
  subnetwork = var.subnetwork_self_link

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  release_channel {
    channel = var.release_channel
  }

  # Workload Identity: this is the ONLY thing required on the GKE side.
  # The federated identity string (project.svc.id.goog[ns/ksa]) is derived
  # automatically - nothing needs manual registration, unlike on AKS where
  # a federated credential resource has to be created explicitly per KSA.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  gateway_api_config {
    channel = var.gateway_api_channel
  }

  # Portfolio/learning cluster - avoid Terraform refusing to destroy it.
  deletion_protection = false
}

resource "google_container_node_pool" "primary" {
  name     = "${var.cluster_name}-primary"
  project  = var.project_id
  location = var.zone
  cluster  = google_container_cluster.this.name

  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb

    # Required at the node level for pods to actually use Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
