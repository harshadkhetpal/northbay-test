#!/bin/bash
# =============================================================================
# Bootstrap Script for Terraform Backend Infrastructure
# =============================================================================
# This script creates the complete Terraform backend infrastructure:
#   1. Resource Group (if doesn't exist)
#   2. Storage Account (if doesn't exist)
#   3. Storage Container (if doesn't exist)
#   4. Key Vault (if doesn't exist)
#   5. Seeds secrets in Key Vault for Terraform backend configuration
#
# Usage:
#   ./secrets.sh
#   # Or with custom values:
#   RG_NAME=custom-rg SA_NAME=customsa ./secrets.sh
#
# Prerequisites:
#   - Azure CLI installed and authenticated (az login)
#   - Appropriate permissions to create resources
# =============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (can be overridden via environment variables)
RG_NAME="${TERRAFORM_BACKEND_RG:-northbay-tfstate-rg}"
SA_NAME="${TERRAFORM_BACKEND_SA:-northbaytfstate}"
CONTAINER_NAME="${TERRAFORM_BACKEND_CONTAINER:-tfstate}"
KV_NAME="${TERRAFORM_BACKEND_KV:-kv-northbay}"
LOCATION="${LOCATION:-eastus}"

# Validation functions
check_azure_cli() {
  if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed.${NC}"
    echo "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
  fi
}

check_azure_login() {
  if ! az account show >/dev/null 2>&1; then
    echo -e "${YELLOW}Not logged in to Azure. Please run: az login${NC}"
    exit 1
  fi
}

# Print functions
print_header() {
  echo -e "\n${BLUE}=============================================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}=============================================================================${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

# Main execution
main() {
  print_header "Terraform Backend Bootstrap Script"
  
  echo -e "${BLUE}Configuration:${NC}"
  echo "  Resource Group:    $RG_NAME"
  echo "  Storage Account:   $SA_NAME"
  echo "  Container:        $CONTAINER_NAME"
  echo "  Key Vault:         $KV_NAME"
  echo "  Location:         $LOCATION"
  echo ""
  
  # Validation
  print_info "Validating prerequisites..."
  check_azure_cli
  check_azure_login
  
  subscription_name=$(az account show --query name -o tsv)
  subscription_id=$(az account show --query id -o tsv)
  print_success "Using subscription: $subscription_name ($subscription_id)"
  
  # Step 1: Create Resource Group
  print_header "Step 1: Creating Resource Group"
  if ! az group show --name "$RG_NAME" >/dev/null 2>&1; then
    print_info "Creating resource group: $RG_NAME in $LOCATION"
    az group create --name "$RG_NAME" --location "$LOCATION" >/dev/null
    print_success "Resource group created: $RG_NAME"
  else
    print_success "Resource group already exists: $RG_NAME"
  fi
  
  # Step 2: Create Storage Account
  print_header "Step 2: Creating Storage Account"
  if ! az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" >/dev/null 2>&1; then
    print_info "Creating storage account: $SA_NAME"
    
    # Check if name is available
    if ! az storage account check-name --name "$SA_NAME" --query nameAvailable -o tsv | grep -q "true"; then
      print_error "Storage account name '$SA_NAME' is not available globally"
      print_info "Storage account names must be unique across all Azure accounts"
      print_info "Please set SA_NAME environment variable with a unique name"
      exit 1
    fi
    
    az storage account create \
      --name "$SA_NAME" \
      --resource-group "$RG_NAME" \
      --location "$LOCATION" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --allow-blob-public-access false \
      --https-only true \
      >/dev/null
    
    # Wait for storage account to be fully provisioned
    print_info "Waiting for storage account to be ready..."
    az storage account wait --name "$SA_NAME" --resource-group "$RG_NAME" --created --timeout 60
    
    print_success "Storage account created: $SA_NAME"
  else
    print_success "Storage account already exists: $SA_NAME"
  fi
  
  # Step 3: Create Storage Container
  print_header "Step 3: Creating Storage Container"
  if az storage container show \
    --name "$CONTAINER_NAME" \
    --account-name "$SA_NAME" \
    --auth-mode login \
    >/dev/null 2>&1; then
    print_success "Storage container already exists: $CONTAINER_NAME"
  else
    print_info "Creating storage container: $CONTAINER_NAME"
    az storage container create \
      --name "$CONTAINER_NAME" \
      --account-name "$SA_NAME" \
      --auth-mode login \
      --only-show-errors \
      >/dev/null
    print_success "Storage container created: $CONTAINER_NAME"
  fi
  
  # Step 4: Create Key Vault
  print_header "Step 4: Creating Key Vault"
  if ! az keyvault show --name "$KV_NAME" --resource-group "$RG_NAME" >/dev/null 2>&1; then
    print_info "Creating Key Vault: $KV_NAME"
    
    # Check if Key Vault name is available
    if ! az keyvault check-name --name "$KV_NAME" --query nameAvailable -o tsv | grep -q "true"; then
      print_error "Key Vault name '$KV_NAME' is not available globally"
      print_info "Key Vault names must be unique across all Azure accounts"
      print_info "Please set KV_NAME environment variable with a unique name"
      exit 1
    fi
    
    az keyvault create \
      --name "$KV_NAME" \
      --resource-group "$RG_NAME" \
      --location "$LOCATION" \
      --enable-purge-protection true \
      --enable-soft-delete true \
      --sku standard \
      >/dev/null
    
    print_success "Key Vault created: $KV_NAME"
  else
    print_success "Key Vault already exists: $KV_NAME"
  fi
  
  # Step 5: Retrieve Storage Account Key
  print_header "Step 5: Retrieving Storage Account Key"
  print_info "Retrieving primary access key for storage account..."
  sa_key=$(az storage account keys list \
    --resource-group "$RG_NAME" \
    --account-name "$SA_NAME" \
    --query '[0].value' -o tsv)
  
  if [[ -z "$sa_key" ]]; then
    print_error "Failed to retrieve key for storage account $SA_NAME"
    exit 1
  fi
  print_success "Storage account key retrieved successfully"
  
  # Step 6: Store Secrets in Key Vault
  print_header "Step 6: Seeding Secrets in Key Vault"
  
  create_or_update_secret() {
    local secret_name=$1
    local secret_value=$2
    local existing_value
    
    existing_value=$(az keyvault secret show \
      --name "$secret_name" \
      --vault-name "$KV_NAME" \
      --query value -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$existing_value" ]]; then
      print_info "Creating secret: $secret_name"
      az keyvault secret set \
        --vault-name "$KV_NAME" \
        --name "$secret_name" \
        --value "$secret_value" \
        >/dev/null
      print_success "Secret created: $secret_name"
    else
      print_warning "Secret already exists: $secret_name (skipping update for safety)"
    fi
  }
  
  create_or_update_secret "terraformBackendResourceGroupName" "$RG_NAME"
  create_or_update_secret "terraformBackendStorageAccountName" "$SA_NAME"
  create_or_update_secret "terraformBackendContainerName" "$CONTAINER_NAME"
  create_or_update_secret "terraformBackendStorageAccountKey" "$sa_key"
  
  # Step 7: Summary and Next Steps
  print_header "Setup Complete!"
  
  echo -e "${GREEN}Summary of created resources:${NC}"
  echo "  Resource Group:    $RG_NAME"
  echo "  Storage Account:   $SA_NAME"
  echo "  Container:         $CONTAINER_NAME"
  echo "  Key Vault:         $KV_NAME"
  echo ""
  
  echo -e "${BLUE}Next Steps:${NC}"
  echo ""
  echo "1. Link Key Vault to Azure DevOps Variable Group:"
  echo "   - Go to Azure DevOps → Pipelines → Library"
  echo "   - Create or edit variable group: 'global-variables'"
  echo "   - Enable 'Link secrets from an Azure Key Vault as variables'"
  echo "   - Select Key Vault: $KV_NAME"
  echo "   - Link these secrets:"
  echo "     • terraformBackendResourceGroupName"
  echo "     • terraformBackendStorageAccountName"
  echo "     • terraformBackendContainerName"
  echo "     • terraformBackendStorageAccountKey"
  echo ""
  echo "2. See KEY_VAULT_PIPELINE_SETUP.md for detailed instructions"
  echo ""
  echo "3. Verify the setup:"
  echo "   ./scripts/verify-keyvault-link.sh"
  echo ""
  echo -e "${GREEN}All done! Your Terraform backend infrastructure is ready.${NC}"
  echo ""
}

# Run main function
main
