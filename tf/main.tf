terraform {
  required_version = "~> 1.6"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.10.0"
    }
  }
  backend "s3" {
    bucket                      = "g4e-dggs-state"
    key                         = "jupyterhub.tfstate"
    region                      = "gra"
    endpoint                    = "https://s3.gra.io.cloud.ovh.net"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_region_validation      = true
  }
}

provider "ovh" {
  endpoint = "ovh-eu"
}

locals {
  service_name = "24b43ff90f3044c8923063b0fbb53f26"
  domain       = "g4e-dggs.duckdns.org"
  namespace    = "jupyterhub"
}

data "ovh_cloud_project_kube" "cluster" {
  service_name = local.service_name
  kube_id      = var.kube_id
}

provider "kubernetes" {
  host                   = data.ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].host
  client_certificate     = base64decode(data.ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_certificate)
  client_key             = base64decode(data.ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_key)
  cluster_ca_certificate = base64decode(data.ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].host
    client_certificate     = base64decode(data.ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_certificate)
    client_key             = base64decode(data.ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].client_key)
    cluster_ca_certificate = base64decode(data.ovh_cloud_project_kube.cluster.kubeconfig_attributes[0].cluster_ca_certificate)
  }
}

resource "kubernetes_namespace" "jupyterhub" {
  metadata {
    name = local.namespace
  }
  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  namespace  = local.namespace
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx-jupyterhub"
  }
  set {
    name  = "controller.ingressClass"
    value = "nginx-jupyterhub"
  }
  set {
    name  = "controller.ingressClassResource.controllerValue"
    value = "k8s.io/ingress-nginx-jupyterhub"
  }

  depends_on = [kubernetes_namespace.jupyterhub]
}

resource "helm_release" "jupyterhub" {
  name       = "jupyterhub"
  namespace  = local.namespace
  repository = "https://hub.jupyter.org/helm-chart/"
  chart      = "jupyterhub"
  version    = "4.3.2"
  timeout    = 600

  values = [
    file("${path.module}/secrets/values.yaml"),
    file("${path.module}/values.yaml"),
  ]

  set {
    name  = "hub.config.JupyterHub.authenticator_class"
    value = "github"
  }
  set {
    name  = "hub.config.GitHubOAuthenticator.oauth_callback_url"
    value = "https://${local.domain}/hub/oauth_callback"
  }
  set {
    name  = "hub.config.GitHubOAuthenticator.allowed_users"
    value = "{allixender,annefou,benbovy,capetienne,cgueguen,j34ni,fpaulifr,keewis,kmch,luikiris,jmdelouis,pablo-richard,tik65536,tinaok}"
  }
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.ingressClassName"
    value = "nginx-jupyterhub"
  }
  set {
    name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-jupyterhub"
  }
  set {
    name  = "ingress.hosts[0]"
    value = local.domain
  }
  set {
    name  = "ingress.tls[0].hosts[0]"
    value = local.domain
  }
  set {
    name  = "ingress.tls[0].secretName"
    value = "jupyterhub-tls"
  }
  set {
    name  = "singleuser.image.name"
    value = "pangeo/pangeo-notebook"
  }
  set {
    name  = "singleuser.image.tag"
    value = "2025.05.22"
  }
  set {
    name  = "singleuser.storage.type"
    value = "dynamic"
  }
  set {
    name  = "singleuser.storage.capacity"
    value = "20Gi"
  }
  set {
    name  = "singleuser.storage.dynamic.storageClass"
    value = "csi-cinder-high-speed"
  }
  set {
    name  = "singleuser.cpu.limit"
    value = "16"
  }
  set {
    name  = "singleuser.cpu.guarantee"
    value = "2"
  }
  set {
    name  = "singleuser.memory.limit"
    value = "32G"
  }
  set {
    name  = "singleuser.memory.guarantee"
    value = "8G"
  }
  set {
    name  = "singleuser.nodeSelector.hub\\.jupyter\\.org/node-purpose"
    value = "user"
  }

  depends_on = [helm_release.ingress_nginx]
}

resource "helm_release" "dask_gateway" {
  name       = "dask-gateway"
  namespace  = local.namespace
  repository = "https://helm.dask.org"
  chart      = "dask-gateway"
  version    = "2025.4.0"
  timeout    = 300

  values = [
    file("${path.module}/dask-gateway-values.yaml"),
  ]

  depends_on = [helm_release.jupyterhub]
}

resource "kubernetes_network_policy" "singleuser_dask" {
  metadata {
    name      = "singleuser-dask-gateway"
    namespace = local.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "app"       = "jupyterhub"
        "component" = "singleuser-server"
        "release"   = "jupyterhub"
      }
    }

    egress {
      ports {
        port     = "8000"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/component" = "traefik"
            "app.kubernetes.io/instance"  = "dask-gateway"
            "app.kubernetes.io/name"      = "dask-gateway"
          }
        }
      }
    }

    policy_types = ["Egress"]
  }
}
