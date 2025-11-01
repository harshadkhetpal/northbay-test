output "tenant_id" {
  description = "Azure tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.name
}

output "key_vault_id" {
  description = "Resource ID of the Key Vault"
  value       = module.key_vault.id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks_cluster.name
}

output "aks_workload_identity_client_id" {
  description = "Client ID of the AKS workload identity (managed identity)"
  value       = module.aks_cluster.workload_identity_client_id
  sensitive   = false
}

output "aks_workload_identity_principal_id" {
  description = "Principal ID of the AKS workload identity"
  value       = module.aks_cluster.workload_identity_principal_id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.container_registry.name
}

output "acr_login_server" {
  description = "Login server URL of the Azure Container Registry"
  value       = module.container_registry.login_server
}

# Output for Helm chart configuration
output "helm_values_workload_identity" {
  description = "Workload identity configuration for Helm values"
  value = {
    tenant_id                 = data.azurerm_client_config.current.tenant_id
    key_vault_name           = module.key_vault.name
    workload_identity_client_id = module.aks_cluster.workload_identity_client_id
  }
  sensitive = false
}

