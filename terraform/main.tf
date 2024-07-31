terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.107.0" 
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "eventhub_resource_group" {
  name     = var.resource_group_name
  location = var.location
}

variable "service_principal_object_id" {
  description = "The object ID of the service principal used for authentication"
  type        = string
}

variable "kubernetes_namespaces" {
  description = "List of namespaces to create in the AKS cluster"
  type        = list(string)
  default     = ["bookstore-frontend", "controller", "flux-system"]
}


# Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                = "${var.resource_group_name}-kv"
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "Purge",
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore","Purge"
    ]

    certificate_permissions = [
      "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]
  }
}

resource "azurerm_key_vault_access_policy" "workload_identity" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.workload_identity.principal_id

  secret_permissions = [
    "Get", "List",
  ]
}


resource "time_sleep" "wait_60_seconds" {
  depends_on = [azurerm_key_vault.keyvault]
  create_duration = "60s"
}


# EventHub Namespace
resource "azurerm_eventhub_namespace" "eventhub_namespace" {
  name                = var.eventhub_namespace_name
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  sku                 = "Standard"
  capacity            = 2
}

# EventHub Connection String Secret
resource "azurerm_key_vault_secret" "eventhub_connection_string" {
  name         = "eventhub-connection-string"
  value        = azurerm_eventhub_namespace.eventhub_namespace.default_primary_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id

   depends_on = [azurerm_key_vault.keyvault]
}

resource "azurerm_eventhub" "eventhub" {
  name                = var.eventhub_name
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  partition_count     = 2
  message_retention   = 1
}


# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.resource_group_name}-aks"
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  dns_prefix          = "${var.resource_group_name}-aks"

  default_node_pool {
    name       = var.node_pool_name
    node_count = 1
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
}

# User-assigned Managed Identity for Workload Identity
resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "${var.resource_group_name}-workload-identity"
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  location            = azurerm_resource_group.eventhub_resource_group.location
}


# Federated Identity Credential, add addiotnal namespaces as needed.
resource "azurerm_federated_identity_credential" "aks_federated_identity" {
  for_each = toset(["default", "bookstore-frontend", "controller"])

  name                = "${var.resource_group_name}-federated-identity-${each.key}"
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:${each.key}:workload-identity-sa"
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}


# Application Insights
resource "azurerm_application_insights" "app_insights" {
  name                = "${var.resource_group_name}-ai"
  location            = azurerm_resource_group.eventhub_resource_group.location
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  application_type    = "other"
}

# Generate a random password for the PostgreSQL admin account
resource "random_password" "postgresql_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

# Azure Database for PostgreSQL - Single Server
resource "azurerm_postgresql_server" "booksdb" {
  name                     = "${var.resource_group_name}-postgresql"
  resource_group_name      = azurerm_resource_group.eventhub_resource_group.name
  location                 = azurerm_resource_group.eventhub_resource_group.location
  version                  = "11"
  administrator_login      = "psqladminun"
  administrator_login_password = random_password.postgresql_admin_password.result
  sku_name                 = "B_Gen5_1"
  storage_mb               = 5120
  ssl_enforcement_enabled  = true

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false
}

# PostgreSQL Database
resource "azurerm_postgresql_database" "booksdb" {
  name                = "booksdb"
  resource_group_name = azurerm_resource_group.eventhub_resource_group.name
  server_name         = azurerm_postgresql_server.booksdb.name
  charset             = "UTF8"
  collation           = "en_US.utf8"
}

# Store the PostgreSQL admin username and password in Key Vault
resource "azurerm_key_vault_secret" "postgresql_admin_username" {
  name         = "postgresql-admin-username"
  value        = "psqladminun"
  key_vault_id = azurerm_key_vault.keyvault.id

   depends_on = [azurerm_key_vault.keyvault]
}

resource "azurerm_key_vault_secret" "postgresql_admin_password" {
  name         = "postgresql-admin-password"
  value        = random_password.postgresql_admin_password.result
  key_vault_id = azurerm_key_vault.keyvault.id

   depends_on = [azurerm_key_vault.keyvault]
}

locals {
  postgresql_connection_string = "Host=${azurerm_postgresql_server.booksdb.fqdn};Database=booksdb;Username=${azurerm_postgresql_server.booksdb.administrator_login}@${azurerm_postgresql_server.booksdb.name};Password=${random_password.postgresql_admin_password.result};Port=5432;"
}

resource "azurerm_key_vault_secret" "postgresql_connection_string" {
  name         = "postgresql-connection-string"
  value        = local.postgresql_connection_string
  key_vault_id = azurerm_key_vault.keyvault.id

   depends_on = [azurerm_key_vault.keyvault]
}

resource "azurerm_kubernetes_cluster_extension" "flux" {
  name                  = "flux"
  cluster_id            = azurerm_kubernetes_cluster.aks.id
  extension_type        = "microsoft.flux"

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_kubernetes_flux_configuration" "k8s_flux" {
  name       = "flux-system"
  cluster_id = azurerm_kubernetes_cluster.aks.id
  namespace  = "flux-system"

  git_repository {
    url             = "https://github.com/tx99/eventhub-lab.git"
    reference_type  = "branch"
    reference_value = "master"
  }

  kustomizations {
    name                      = "ingress"
    path                      = "./k8/templates"
    sync_interval_in_seconds  = 120
    retry_interval_in_seconds = 120
  }

  kustomizations {
    name                      = "frontend"
    path                      = "./src/frontend/k8"
    sync_interval_in_seconds  = 120
    retry_interval_in_seconds = 120
  }

 kustomizations {
    name = "workload-identity"
    path = ".k8/workload-identity/overlays/multi-namespace"
    sync_interval_in_seconds = 120
    retry_interval_in_seconds = 120
    timeout_in_seconds = 300
  }

  kustomizations {
  name = "controller"
  path = "./src/controller/k8"
  sync_interval_in_seconds = 120
  retry_interval_in_seconds = 120
}

  scope = "cluster"

  depends_on = [
    kubernetes_namespace.namespaces,
    azurerm_kubernetes_cluster_extension.flux,
    kubernetes_secret.flux_secrets,
    kubernetes_config_map.flux_custom_values
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "kubernetes_namespace" "namespaces" {
  for_each = toset(var.kubernetes_namespaces)

  metadata {
    name = each.key
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_secret" "flux_secrets" {
  metadata {
    name      = "flux-secrets"
    namespace = "flux-system"
  }

  data = {
    key_vault_url = base64encode(azurerm_key_vault.keyvault.vault_uri)
  }

  depends_on = [kubernetes_namespace.namespaces["flux-system"], azurerm_kubernetes_cluster_extension.flux]
}
resource "kubernetes_config_map" "flux_custom_values" {
  metadata {
    name      = "flux-custom-values"
    namespace = "flux-system"
  }

  data = {
    managed_identity_client_id = azurerm_user_assigned_identity.workload_identity.client_id
    key_vault_url              = azurerm_key_vault.keyvault.vault_uri
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_config_map" "eventhub_config" {
  metadata {
    name      = "eventhub-config"
    namespace = "controller"  
  }

  data = {
    AZURE_EVENTHUB_NAMESPACE = var.eventhub_namespace_name
    AZURE_EVENTHUB_NAME      = var.eventhub_name
  }

  depends_on = [kubernetes_namespace.namespaces]
}


resource "kubernetes_config_map" "workload_identity_config" {
  for_each = toset(var.kubernetes_namespaces)

  metadata {
    name      = "workload-identity-config"
    namespace = each.key
  }

  data = {
    managed_identity_client_id = azurerm_user_assigned_identity.workload_identity.client_id
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_config_map" "key_vault_config" {
  for_each = toset(var.kubernetes_namespaces)

  metadata {
    name      = "key-vault-config"
    namespace = each.key
  }

  data = {
    KEY_VAULT_URL = azurerm_key_vault.keyvault.vault_uri
  }

  depends_on = [kubernetes_namespace.namespaces]
}

resource "kubernetes_role_binding" "flux_custom_values_reader" {
  metadata {
    name      = "flux-custom-values-reader"
    namespace = "flux-system"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "flux-custom-values-reader"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "bookstore-frontend"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "controller"
  }
}

resource "kubernetes_role" "flux_custom_values_reader" {
  metadata {
    name      = "flux-custom-values-reader"
    namespace = "flux-system"
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    resource_names = ["flux-custom-values"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_service_account" "workload_identity_sa" {
  for_each = toset(var.kubernetes_namespaces)

  metadata {
    name      = "workload-identity-sa"
    namespace = each.key
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.workload_identity.client_id
    }
  }

  depends_on = [kubernetes_namespace.namespaces]
}

# Output the Client ID of the Managed Identity
output "workload_identity_client_id" {
  value = azurerm_user_assigned_identity.workload_identity.client_id
}