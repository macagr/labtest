terraform {
  required_version = ">= 1.4.0"

  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.56"
    }
  }
}

# Provider reads EXOSCALE_API_KEY / EXOSCALE_API_SECRET from environment
provider "exoscale" {}

####################
# Variables
####################

variable "zone" {
  description = "Exoscale zone for the SKS cluster"
  type        = string
  default     = "de-fra-1"
}

variable "cluster_name" {
  description = "Name of the SKS cluster"
  type        = string
  default     = "opa-test"
}

####################
# SKS Cluster (control plane)
####################

resource "exoscale_sks_cluster" "opa" {
  zone          = var.zone
  name          = var.cluster_name
  service_level = "starter" # free control plane, good for dev/test
}

####################
# Security group for SKS nodes
####################

resource "exoscale_security_group" "sks_nodes" {
  name = "${var.cluster_name}-nodes"
}

# Allow all egress (nodes can reach internet, JFrog, etc.)
resource "exoscale_security_group_rule" "sks_nodes_egress_all" {
  security_group_id = exoscale_security_group.sks_nodes.id

  description = "Allow all egress"
  type        = "EGRESS"
  protocol    = "tcp"
  start_port  = 1
  end_port    = 65535
  cidr        = "0.0.0.0/0"
}

# Allow all ingress (simple for experiments – tighten for production!)
resource "exoscale_security_group_rule" "sks_nodes_ingress_all" {
  security_group_id = exoscale_security_group.sks_nodes.id

  description = "Allow all ingress (dev/testing only)"
  type        = "INGRESS"
  protocol    = "tcp"
  start_port  = 1
  end_port    = 65535
  cidr        = "0.0.0.0/0"
}

####################
# Nodepool (worker nodes)
####################

resource "exoscale_sks_nodepool" "default" {
  zone       = var.zone
  cluster_id = exoscale_sks_cluster.opa.id

  name = "default"

  # SKS doesn't support micro/tiny – use small as the cheapest option
  instance_type = "standard.small"
  size          = 1

  # Attach the security group so the NLB + internet can reach the nodes
  security_group_ids = [exoscale_security_group.sks_nodes.id]
}

####################
# Admin kubeconfig
####################

resource "exoscale_sks_kubeconfig" "admin" {
  cluster_id = exoscale_sks_cluster.opa.id
  zone       = exoscale_sks_cluster.opa.zone

  user   = "kubernetes-admin"
  groups = ["system:masters"]

  # 7 days – good enough for experiments; update as you like
  ttl_seconds = 604800
}

####################
# Outputs
####################

output "sks_api_endpoint" {
  description = "Public Kubernetes API endpoint"
  value       = exoscale_sks_cluster.opa.endpoint
}

output "kubeconfig" {
  description = "Admin kubeconfig (sensitive)"
  value       = exoscale_sks_kubeconfig.admin.kubeconfig
  sensitive   = true
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
