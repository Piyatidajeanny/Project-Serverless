terraform {
  required_version = ">= 1.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# ============================================
# Kubernetes Namespace
# ============================================

resource "kubernetes_namespace_v1" "medicine_namespace" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
      app  = "medicine-stock"
    }
  }

  depends_on = []
}

# ============================================
# ConfigMap for Application Configuration
# ============================================

resource "kubernetes_config_map_v1" "app_config" {
  metadata {
    name      = "medicine-stock-config"
    namespace = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
  }

  data = {
    DB_PATH           = "/app/medicine.db"
    PYTHONUNBUFFERED  = "1"
    LOG_LEVEL         = var.log_level
    ENVIRONMENT       = var.environment
  }
}

# ============================================
# Secret for Sensitive Data
# ============================================

resource "kubernetes_secret_v1" "app_secrets" {
  metadata {
    name      = "medicine-stock-secrets"
    namespace = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
  }

  type = "Opaque"

  data = {
    DOCKER_REGISTRY_USERNAME = base64encode(var.docker_username)
    DOCKER_REGISTRY_PASSWORD = base64encode(var.docker_password)
  }

  depends_on = [kubernetes_namespace_v1.medicine_namespace]
}

# ============================================
# ServiceAccount
# ============================================

resource "kubernetes_service_account_v1" "medicine_stock" {
  metadata {
    name      = "medicine-stock-sa"
    namespace = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
  }

  depends_on = [kubernetes_namespace_v1.medicine_namespace]
}

# ============================================
# Role for Pod Permissions
# ============================================

resource "kubernetes_role_v1" "medicine_stock" {
  metadata {
    name      = "medicine-stock-role"
    namespace = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list"]
  }

  depends_on = [kubernetes_namespace_v1.medicine_namespace]
}

# ============================================
# RoleBinding
# ============================================

resource "kubernetes_role_binding_v1" "medicine_stock" {
  metadata {
    name      = "medicine-stock-role-binding"
    namespace = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.medicine_stock.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.medicine_stock.metadata[0].name
    namespace = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
  }

  depends_on = [
    kubernetes_role_v1.medicine_stock,
    kubernetes_service_account_v1.medicine_stock
  ]
}

# ============================================
# NetworkPolicy (Optional - Security)
# ============================================

resource "kubernetes_network_policy_v1" "medicine_stock" {
  metadata {
    name      = "medicine-stock-netpol"
    namespace = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "medicine-stock"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace_v1.medicine_namespace.metadata[0].name
          }
        }
      }
      to {
        pod_selector {}
      }
    }
  }

  depends_on = [kubernetes_namespace_v1.medicine_namespace]
}