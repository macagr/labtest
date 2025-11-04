terraform {
  required_version = ">= 1.4.0"

  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.56"
    }
  }
}

# Provider will read EXOSCALE_API_KEY and EXOSCALE_API_SECRET from env vars
provider "exoscale" {}

variable "zone" {
  description = "Exoscale zone"
  type        = string
  default     = "de-fra-1"
}

variable "cluster_name" {
  description = "Name of the SKS cluster"
  type        = string
  default     = "opa-test"
}

# SKS cluster (Starter = free control plane, good for testing)
resource "exoscale_sks_cluster" "opa" {
  zone          = var.zone
  name          = var.cluster_name
  service_level = "starter"
}

resource "exoscale_sks_nodepool" "default" {
  zone       = var.zone
  cluster_id = exoscale_sks_cluster.opa.id

  name = "default"

  # SKS does NOT support micro/tiny -> use small as the cheapest option
  instance_type = "standard.small"
  size          = 1
}

# Admin kubeconfig for this cluster
resource "exoscale_sks_kubeconfig" "admin" {
  cluster_id = exoscale_sks_cluster.opa.id
  zone       = exoscale_sks_cluster.opa.zone

  user   = "kubernetes-admin"
  groups = ["system:masters"]
}


output "sks_api_endpoint" {
  description = "Public Kubernetes API endpoint"
  value       = exoscale_sks_cluster.opa.endpoint
}

output "kubeconfig" {
  description = "Admin kubeconfig (sensitive)"
  value       = exoscale_sks_kubeconfig.admin.kubeconfig
  sensitive   = true
}
