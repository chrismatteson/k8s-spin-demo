provider "azurerm" {
  features {
  }
}

resource "random_id" "cluster_name" {
  byte_length = 4
}

# Local for tag to attach to all items
locals {
  tags = merge(
    var.tags,
    {
      "ClusterName" = random_id.cluster_name.hex
    },
  )
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${random_id.cluster_name.hex}"
  location = "West US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${random_id.cluster_name.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "spin-${random_id.cluster_name.hex}"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "np" {
  name                  = "spin${random_id.cluster_name.hex}"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_DS2_v2"
  node_count            = 1
  workload_runtime      = "WasmWasi"

  tags = local.tags
}