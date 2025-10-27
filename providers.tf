terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.44.1"
    }
  }
}

provider "azurerm" {

  features {

    key_vault {
      purge_soft_delete_on_destroy       = false

    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    virtual_machine {
      delete_os_disk_on_deletion  = true
      graceful_shutdown           = true
    }

    managed_disk {
      expand_without_downtime = true
    }

    app_service {
      force_delete_disassociated = true
    }

    kubernetes_cluster {
      prevent_deletion_if_contains_resources = true
    }

    network_security_group {
      ignore_rule_changes = false
    }
    monitor {
      retain_log_analytics_workspace = false
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}
}