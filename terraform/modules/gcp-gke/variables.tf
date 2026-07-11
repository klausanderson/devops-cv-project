variable "project_id" {
  type = string
}

variable "region" {
  description = "Used only for labeling/outputs; the cluster itself is zonal (see `zone`)"
  type        = string
}

variable "zone" {
  description = "Zonal location for the cluster control plane and node pool (e.g. europe-central2-a)"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "network_self_link" {
  type = string
}

variable "subnetwork_self_link" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "node_count" {
  type    = number
  default = 2
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "gateway_api_channel" {
  description = "CHANNEL_STANDARD (matches --gateway-api=standard) or CHANNEL_DISABLED"
  type        = string
  default     = "CHANNEL_STANDARD"
}
