#!/bin/bash
# =============================================================================
# Verification Script for Key Vault → Azure DevOps Pipeline Integration
# =============================================================================
# This script verifies that:
#   1. Key Vault exists and is accessible
#   2. All required secrets exist in Key Vault
#   3. Azure DevOps Service Principal has access (if authenticated)
#
# Usage:
#   ./scripts/verify-keyvault-link.sh [KEY_VAULT_NAME] [RESOURCE_GROUP]
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
KV_NAME="${1:-kv-northbay}"
RG_NAME="${2:-northbay-tfstate-rg}"

# Required secrets
REQUIRED_SECRETS=(
  "terraformBackendResourceGroupName"
  "terraformBackendStorageAccountName"
  "terraformBackendContainerName"
  "terraformBackendStorageAccountKey"
)

print_header() {
  echo -e "\n${BLUE}=============================================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}=============================================================================${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

check_azure_cli() {
  if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    exit 1
  fi
}

check_azure_login() {
  if ! az account show >/dev/null 2>&1; then
    print_error "Not logged in to Azure. Run: az login"
    exit 1
  fi
}

verify_key_vault() {
  print_header "Verifying Key Vault"
  
  if ! az keyvault show --name "$KV_NAME" --resource-group "$RG_NAME" >/dev/null 2>&1; then
    print_error "Key Vault '$KV_NAME' not found in resource group '$RG_NAME'"
    print_info "Run ./key-vault/secrets.sh first to create the Key Vault"
    return 1
  fi
  
  print_success "Key Vault exists: $KV_NAME"
  
  # Get Key Vault URI
  kv_uri=$(az keyvault show --name "$KV_NAME" --resource-group "$RG_NAME" --query properties.vaultUri -o tsv)
  print_info "Key Vault URI: $kv_uri"
  
  return 0
}

verify_secrets() {
  print_header "Verifying Secrets"
  
  local all_found=true
  local missing_secrets=()
  
  for secret in "${REQUIRED_SECRETS[@]}"; do
    if az keyvault secret show --name "$secret" --vault-name "$KV_NAME" >/dev/null 2>&1; then
      # Get secret value (but don't display sensitive ones)
      if [[ "$secret" == *"Key"* ]]; then
        print_success "Secret exists: $secret (value hidden)"
      else
        secret_value=$(az keyvault secret show --name "$secret" --vault-name "$KV_NAME" --query value -o tsv)
        print_success "Secret exists: $secret = $secret_value"
      fi
    else
      print_error "Secret missing: $secret"
      missing_secrets+=("$secret")
      all_found=false
    fi
  done
  
  if [[ "$all_found" == true ]]; then
    print_success "All required secrets are present in Key Vault"
    return 0
  else
    print_error "Missing secrets: ${missing_secrets[*]}"
    print_info "Run ./key-vault/secrets.sh to create missing secrets"
    return 1
  fi
}

verify_storage_account() {
  print_header "Verifying Storage Account"
  
  sa_name=$(az keyvault secret show \
    --name "terraformBackendStorageAccountName" \
    --vault-name "$KV_NAME" \
    --query value -o tsv)
  
  rg_name=$(az keyvault secret show \
    --name "terraformBackendResourceGroupName" \
    --vault-name "$KV_NAME" \
    --query value -o tsv)
  
  if az storage account show --name "$sa_name" --resource-group "$rg_name" >/dev/null 2>&1; then
    print_success "Storage account exists: $sa_name"
    
    container_name=$(az keyvault secret show \
      --name "terraformBackendContainerName" \
      --vault-name "$KV_NAME" \
      --query value -o tsv)
    
    if az storage container show \
      --name "$container_name" \
      --account-name "$sa_name" \
      --auth-mode login \
      >/dev/null 2>&1; then
      print_success "Storage container exists: $container_name"
    else
      print_error "Storage container not found: $container_name"
      return 1
    fi
    
    return 0
  else
    print_error "Storage account not found: $sa_name"
    return 1
  fi
}

check_service_principal_access() {
  print_header "Checking Service Principal Access"
  
  # Get current service principal (if running as service principal)
  sp_id=$(az account show --query user.type -o tsv 2>/dev/null || echo "User")
  
  if [[ "$sp_id" == "servicePrincipal" ]]; then
    print_info "Running as Service Principal"
    current_sp=$(az account show --query user.name -o tsv)
    print_info "Service Principal: $current_sp"
    
    # Check if service principal has access to Key Vault
    if az keyvault show \
      --name "$KV_NAME" \
      --resource-group "$RG_NAME" \
      --query "properties.accessPolicies[?objectId=='$(az ad signed-in-user show --query id -o tsv)']" \
      >/dev/null 2>&1; then
      print_success "Service Principal has access to Key Vault"
    else
      print_error "Service Principal may not have access to Key Vault"
      print_info "Grant access in Azure Portal or run:"
      echo "  az keyvault set-policy --name $KV_NAME --upn $(az account show --query user.name -o tsv) --secret-permissions get list"
    fi
  else
    print_info "Running as User account"
    print_info "Azure DevOps Service Principal access must be configured separately"
    print_info "This is typically done when linking Key Vault to Variable Group in Azure DevOps"
  fi
}

main() {
  print_header "Key Vault Pipeline Integration Verification"
  
  echo "Configuration:"
  echo "  Key Vault:         $KV_NAME"
  echo "  Resource Group:    $RG_NAME"
  echo ""
  
  # Validation
  check_azure_cli
  check_azure_login
  
  # Run checks
  local exit_code=0
  
  verify_key_vault || exit_code=1
  verify_secrets || exit_code=1
  verify_storage_account || exit_code=1
  check_service_principal_access
  
  # Summary
  print_header "Verification Summary"
  
  if [[ $exit_code -eq 0 ]]; then
    print_success "All checks passed!"
    echo ""
    print_info "Next steps:"
    echo "  1. Link Key Vault to Azure DevOps Variable Group (see KEY_VAULT_PIPELINE_SETUP.md)"
    echo "  2. Run Terraform pipeline to test the integration"
    echo ""
  else
    print_error "Some checks failed. Please review the errors above."
    echo ""
    print_info "Common fixes:"
    echo "  - Run ./key-vault/secrets.sh to create missing resources"
    echo "  - Ensure you have proper Azure permissions"
    echo "  - Check Key Vault access policies"
    echo ""
    exit 1
  fi
}

main

