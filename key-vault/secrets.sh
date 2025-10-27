#!/bin/bash
set -e

kv_name="kv-northbay"
rg_name="northbay-tfstate-rg"
sa_name="northbaytfstate"
container_name="tfstate"
location="eastus"

az account show >/dev/null 2>&1 || az login -o table
subscription_name=$(az account show --query name -o tsv)
echo "Using subscription: $subscription_name"

if ! az keyvault show --name "$kv_name" --resource-group "$rg_name" >/dev/null 2>&1; then
  echo "Creating Key Vault $kv_name..."
  az keyvault create \
    --name "$kv_name" \
    --resource-group "$rg_name" \
    --location "$location" \
    --enable-purge-protection true \
    --enable-soft-delete true \
    --sku standard >/dev/null
  echo "Key Vault created: $kv_name"
else
  echo "Key Vault $kv_name already exists."
fi

echo "Retrieving Storage Account key..."
sa_key=$(az storage account keys list \
  --resource-group "$rg_name" \
  --account-name "$sa_name" \
  --query '[0].value' -o tsv)

if [[ -z "$sa_key" ]]; then
  echo "Failed to retrieve key for storage account $sa_name"
  exit 1
fi
echo "Retrieved primary key for storage account."

create_or_update_secret () {
  local secret_name=$1
  local secret_value=$2
  local existing_value
  existing_value=$(az keyvault secret show --name "$secret_name" --vault-name "$kv_name" --query value -o tsv 2>/dev/null || echo "")

  if [[ -z "$existing_value" ]]; then
    echo "Creating secret $secret_name..."
    az keyvault secret set --vault-name "$kv_name" --name "$secret_name" --value "$secret_value" >/dev/null
    echo "Secret $secret_name created."
  else
    echo "Secret $secret_name already exists. Skipping."
  fi
}

echo "Seeding Terraform backend secrets in Key Vault..."

create_or_update_secret "terraformBackendResourceGroupName" "$rg_name"
create_or_update_secret "terraformBackendStorageAccountName" "$sa_name"
create_or_update_secret "terraformBackendContainerName" "$container_name"
create_or_update_secret "terraformBackendStorageAccountKey" "$sa_key"

echo "All Terraform backend secrets verified or created successfully."

echo "Summary:"
echo "  Key Vault:         $kv_name"
echo "  Resource Group:    $rg_name"
echo "  Storage Account:   $sa_name"
echo "  Container:         $container_name"

echo "You can now run Terraform init like this:"
echo
echo "terraform init \\"
echo "  -backend-config=\"resource_group_name=$(az keyvault secret show --vault-name $kv_name --name terraformBackendResourceGroupName --query value -o tsv)\" \\"
echo "  -backend-config=\"storage_account_name=$(az keyvault secret show --vault-name $kv_name --name terraformBackendStorageAccountName --query value -o tsv)\" \\"
echo "  -backend-config=\"container_name=$(az keyvault secret show --vault-name $kv_name --name terraformBackendContainerName --query value -o tsv)\" \\"
echo "  -backend-config=\"key=infra.tfstate\" \\"
echo "  -backend-config=\"access_key=$(az keyvault secret show --vault-name $kv_name --name terraformBackendStorageAccountKey --query value -o tsv)\""
