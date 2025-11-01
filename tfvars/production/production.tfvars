# Production Environment Terraform Variables
# This file contains production-specific values for infrastructure provisioning

# Resource Naming
resource_group_name = "northbay-prod-rg"
aks_cluster_name = "northbay-prod-aks"
key_vault_name = "northbay-prod-kv"
acr_name = "northbayprodacr"

# Location
location = "eastus"

# Network Configuration
hub_vnet_name = "HubVNet-Prod"
aks_vnet_name = "AksVNet-Prod"

# AKS Configuration
kubernetes_version = ""  # Will be auto-detected by pipeline
sku_tier = "Paid"  # Use Paid tier for production (includes Uptime SLA)

# Node Pool Configuration - Production settings
default_node_pool_vm_size = "Standard_D4s_v3"  # Larger instance for production
default_node_pool_min_count = 3
default_node_pool_max_count = 10
default_node_pool_node_count = 3

additional_node_pool_vm_size = "Standard_D4s_v3"
additional_node_pool_min_count = 3
additional_node_pool_max_count = 10
additional_node_pool_node_count = 3

# Key Vault Configuration - Production security settings
key_vault_enable_rbac_authorization = true
key_vault_purge_protection_enabled = true  # Enable purge protection for production
key_vault_soft_delete_retention_days = 90  # Maximum retention
key_vault_sku_name = "premium"  # Use Premium SKU for production

# Container Registry Configuration
acr_sku = "Premium"  # Use Premium for production (required for private endpoints)
acr_admin_enabled = false  # Disable admin user for security

# Firewall Configuration
firewall_sku_tier = "Premium"  # Use Premium tier for production
firewall_threat_intel_mode = "Deny"  # Deny malicious traffic in production

# Log Analytics
log_analytics_retention_days = 90  # Longer retention for production

# Tags
tags = {
  Environment = "Production"
  ManagedBy = "Terraform"
  Project = "NorthBay"
  CostCenter = "Engineering"
}

