terraform {
  required_version = ">= 1.0"

  provider_meta "equinix" {
    module_name = "equinix-metal-nutanix-cluster"
  }

  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = ">= 1.30"
    }
    # tflint-ignore: terraform_unused_required_providers
    null = {
      source  = "hashicorp/null"
      version = ">= 3"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3"
    }
    # tflint-ignore: terraform_unused_required_providers
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
  }
}

# Configure the Equinix Metal credentials.
provider "equinix" {
  auth_token = var.metal_auth_token
}

locals {
  project_id = var.create_project ? element(equinix_metal_project.nutanix[*].id, 0) : element(data.equinix_metal_project.nutanix[*].id, 0)
  vrf_id     = var.create_vrf ? element(equinix_metal_vrf.nutanix[*].id, 0) : element(data.equinix_metal_vrf.nutanix[*].id, 0)
}

resource "equinix_metal_project" "nutanix" {
  count           = var.create_project ? 1 : 0
  name            = var.metal_project_name
  organization_id = var.metal_organization_id
}

data "equinix_metal_project" "nutanix" {
  count      = var.create_project ? 0 : 1
  name       = var.metal_project_name != "" ? var.metal_project_name : null
  project_id = var.metal_project_id != "" ? var.metal_project_id : null
}

# Common resources shared between both clusters
resource "random_string" "vrf_name_suffix" {
  length  = 5
  special = false
}

resource "equinix_metal_vrf" "nutanix" {
  count       = var.create_vrf ? 1 : 0
  description = "VRF with ASN 65000 and a pool of address space that includes 192.168.96.0/21"
  name        = "nutanix-vrf-${random_string.vrf_name_suffix.result}"
  metro       = var.metal_metro
  local_asn   = "65000"
  ip_ranges   = [var.cluster_subnet]
  project_id  = local.project_id
}

data "equinix_metal_vrf" "nutanix" {
  count  = var.create_vrf ? 0 : 1
  vrf_id = var.vrf_id
}

module "nutanix_cluster1" {
  source             = "equinix-labs/metal-nutanix-cluster/equinix"
  version            = "0.4.0"
  metal_auth_token   = var.metal_auth_token
  metal_metro        = var.metal_metro
  create_project     = false
  nutanix_node_count = var.nutanix_node_count
  metal_project_id   = local.project_id
  cluster_subnet     = "192.168.96.0/22"
  vrf_id             = local.vrf_id
  create_vrf         = false
  create_vlan        = true
}

module "nutanix_cluster2" {
  source             = "equinix-labs/metal-nutanix-cluster/equinix"
  version            = "0.4.0"
  metal_auth_token   = var.metal_auth_token
  metal_metro        = var.metal_metro
  create_project     = false
  nutanix_node_count = var.nutanix_node_count
  metal_project_id   = local.project_id
  cluster_subnet     = "192.168.100.0/22"
  vrf_id             = local.vrf_id
  create_vrf         = false
  create_vlan        = true
}
