data "terraform_remote_state" "aks" {
  backend = "local"
  config = {
    path = "../aks/terraform.tfstate"
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.aks.outputs.aks_host
  username               = data.terraform_remote_state.aks.outputs.aks_username
  password               = data.terraform_remote_state.aks.outputs.aks_password
  client_certificate     = base64decode(data.terraform_remote_state.aks.outputs.aks_client_certificate)
  client_key             = base64decode(data.terraform_remote_state.aks.outputs.aks_client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.aks.outputs.aks_cluster_ca_certificate)
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

resource "kubernetes_manifest" "RuntimeClass" {
  manifest = {
    "apiVersion" = "node.k8s.io/v1"
    "kind"       = "RuntimeClass"
    "metadata" = {
      "name"      = "wasmtime-spin-v1"
    }
    "handler" = "spin"
    "scheduling" = {
      "nodeSelector" = {
        "kubernetes.azure.com/wasmtime-spin-v1" = "true"
      }
    }
  }
}

resource "kubernetes_manifest" "deployment_wasm_spin" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "Deployment"
    "metadata" = {
      "name" = "wasm-spin"
      "namespace" = "default"
    }
    "spec" = {
      "replicas" = 1
      "selector" = {
        "matchLabels" = {
          "app" = "wasm-spin"
        }
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app" = "wasm-spin"
          }
        }
        "spec" = {
          "containers" = [
            {
              "command" = [
                "/",
              ]
              "image" = "ghcr.io/deislabs/containerd-wasm-shims/examples/spin-rust-hello:latest"
              "name" = "testwasm"
            },
          ]
          "runtimeClassName" = "wasmtime-spin-v1"
        }
      }
    }
  }
  depends_on = [
    kubernetes_manifest.RuntimeClass
  ]
}

resource "kubernetes_manifest" "service_wasm_spin" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Service"
    "metadata" = {
      "name" = "wasm-spin"
      "namespace" = "default"
    }
    "spec" = {
      "ports" = [
        {
          "port" = 80
          "protocol" = "TCP"
          "targetPort" = 80
        },
      ]
      "selector" = {
        "app" = "wasm-spin"
      }
      "type" = "LoadBalancer"
    }
  }
}

resource "kubernetes_manifest" "ingress_wasm_ingress" {
  manifest = {
    "apiVersion" = "networking.k8s.io/v1"
    "kind" = "Ingress"
    "metadata" = {
      "annotations" = {
        "ingress.kubernetes.io/ssl-redirect" = "false"
        "kubernetes.io/ingress.class" = "traefik"
      }
      "name" = "wasm-ingress"
      "namespace" = "default"
    }
    "spec" = {
      "rules" = [
        {
          "http" = {
            "paths" = [
              {
                "backend" = {
                  "service" = {
                    "name" = "wasm-spin"
                    "port" = {
                      "number" = 80
                    }
                  }
                }
                "path" = "/"
                "pathType" = "Prefix"
              },
            ]
          }
        },
      ]
    }
  }
}