terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.103.1"
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

resource "azurerm_resource_group" "aks_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_eventhub_namespace" "eventhub_namespace" {
  name                = var.eventhub_namespace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  sku                 = "Standard"
  capacity            = 1
}

resource "azurerm_eventhub" "eventhub" {
  name                = var.eventhub_name
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  resource_group_name = azurerm_resource_group.aks_rg.name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "${var.cluster_name}-dns"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "systempool"
    node_count          = 1
    vm_size             = "Standard_B2s"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 2
    orchestrator_version = var.kubernetes_version
    type                = "VirtualMachineScaleSets"
  }

  network_profile {
    network_plugin  = "azure"
    network_policy  = "azure"
    dns_service_ip  = "10.0.0.10"
    service_cidr    = "10.0.0.0/16"
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    azure_policy {
      enabled = true
    }
    azure_keyvault_secrets_provider {
      enabled = true
      identity {
        type = "UserAssigned"
        user_assigned_identity_id = azurerm_user_assigned_identity.aks_user_assigned_identity.id
      }
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "userpool" {
  name                  = "userpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  vm_size               = "Standard_B2s"
  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 2
  mode                  = "User"
}

resource "azurerm_user_assigned_identity" "aks_user_assigned_identity" {
  name                = "aksUserAssignedIdentity"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
}

resource "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
}

resource "azurerm_key_vault_access_policy" "aks_access_policy" {
  key_vault_id     = azurerm_key_vault.key_vault.id
  tenant_id        = data.azurerm_client_config.current.tenant_id
  object_id        = azurerm_user_assigned_identity.aks_user_assigned_identity.client_id
  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "terraform_access_policy" {
  key_vault_id     = azurerm_key_vault.key_vault.id
  tenant_id        = data.azurerm_client_config.current.tenant_id
  object_id        = data.azurerm_client_config.current.object_id
  secret_permissions = ["Set", "Delete", "Get"]
}

resource "azurerm_eventhub_authorization_rule" "auth_rule" {
  name                = "eventhub-auth-rule"
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  eventhub_name       = azurerm_eventhub.eventhub.name
  resource_group_name = azurerm_resource_group.aks_rg.name
  listen              = true
  send                = true
  manage              = true
}

resource "azurerm_key_vault_secret" "eventhub_connection_string" {
  name         = "EventHubConnectionString"
  value        = azurerm_eventhub_authorization_rule.auth_rule.primary_connection_string
  key_vault_id = azurerm_key_vault.key_vault.id
}

resource "azurerm_kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_manifest" "fluxcd_source" {
  manifest = {
    apiVersion = "source.toolkit.fluxcd.io/v1beta2"
    kind       = "GitRepository"
    metadata = {
      name      = "flux-system"
      namespace = "flux-system"
    }
    spec = {
      interval = "1m"
      url      = var.flux_repo_url
      ref = {
        branch = var.flux_repo_branch
      }
    }
  }
}

resource "kubernetes_manifest" "fluxcd_kustomization" {
  manifest = {
    apiVersion = "kustomize.toolkit.fluxcd.io/v1beta2"
    kind       = "Kustomization"
    metadata = {
      name      = "flux-system"
      namespace = "flux-system"
    }
    spec = {
      interval      = "1m"
      path          = "./terraform/templates"
      prune         = true
      sourceRef = {
        kind = "GitRepository"
        name = "flux-system"
      }
    }
  }
}
