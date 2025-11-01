# Terraform Integration Guide

## Overview

The Helm chart now supports dynamic configuration from Terraform outputs, eliminating the need to hardcode tenant IDs, Key Vault names, or managed identity client IDs.

## Architecture

```
Terraform Apply
    │
    ├─> Creates Infrastructure (AKS, Key Vault, Managed Identity)
    │
    └─> Outputs Configuration Values
            │
            ├─> tenant_id
            ├─> key_vault_name
            ├─> aks_workload_identity_client_id
            └─> etc.
            │
            │
Pipeline Stage: Prepare_Terraform_Values
            │
            ├─> Reads Terraform Outputs
            │
            └─> Generates values-terraform.yaml
                    │
                    │
                Helm Chart Deployment
                    │
                    ├─> Reads values.yaml (base)
                    ├─> Reads values-terraform.yaml (Terraform values)
                    │
                    └─> Merges & Uses terraformConfig values
```

## Terraform Outputs

The following outputs are required and have been added to `terraform/outputs.tf`:

```hcl
output "tenant_id" {
  description = "Azure tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.name
}

output "aks_workload_identity_client_id" {
  description = "Client ID of the AKS workload identity"
  value       = azurerm_user_assigned_identity.aks_identity.client_id
}
```

## How It Works

### 1. Terraform Outputs Values

After running `terraform apply`, these outputs are available:

```bash
terraform output tenant_id
terraform output key_vault_name
terraform output aks_workload_identity_client_id
```

### 2. Pipeline Automatically Generates Values

The pipeline stage `Prepare_Terraform_Values` automatically:
- Reads Terraform outputs
- Generates `chart/values-terraform.yaml` with:
  ```yaml
  terraformConfig:
    enabled: true
    tenantId: "<from-terraform>"
    keyVaultName: "<from-terraform>"
    workloadIdentityClientId: "<from-terraform>"
  
  keyVault:
    enabled: true
    name: "<from-terraform>"
    tenantId: "<from-terraform>"
  ```

### 3. Helm Templates Use Dynamic Values

The Helm templates automatically detect when `terraformConfig.enabled: true` and use those values instead of hardcoded ones:

- **ServiceAccount**: Reads `workloadIdentityClientId` from `terraformConfig`
- **SecretProviderClass**: Reads `tenantId`, `keyVaultName`, and `clientId` from `terraformConfig`

## Manual Usage

### Option 1: Use the Script

Run the script to generate values file:

```bash
cd scripts
./prepare-helm-values-from-terraform.sh
```

This generates `chart/values-terraform.yaml` that you can use with Helm:

```bash
helm upgrade --install nginx-bluegreen ./chart \
  -f chart/values.yaml \
  -f chart/values-terraform.yaml
```

### Option 2: Pass Values Directly

Extract Terraform outputs and pass as Helm values:

```bash
TENANT_ID=$(terraform output -raw tenant_id)
KV_NAME=$(terraform output -raw key_vault_name)
CLIENT_ID=$(terraform output -raw aks_workload_identity_client_id)

helm upgrade --install nginx-bluegreen ./chart \
  --set terraformConfig.enabled=true \
  --set terraformConfig.tenantId=$TENANT_ID \
  --set terraformConfig.keyVaultName=$KV_NAME \
  --set terraformConfig.workloadIdentityClientId=$CLIENT_ID \
  --set keyVault.enabled=true \
  --set keyVault.name=$KV_NAME \
  --set keyVault.tenantId=$TENANT_ID
```

### Option 3: Fallback to Manual Values

If `terraformConfig.enabled: false` (default), the chart falls back to:
- `serviceAccount.workloadIdentityClientId`
- `keyVault.name`
- `keyVault.tenantId`

## Configuration in values.yaml

The `values.yaml` now includes:

```yaml
terraformConfig:
  enabled: false  # Set to true to use Terraform outputs
  tenantId: ""
  keyVaultName: ""
  workloadIdentityClientId: ""

keyVault:
  enabled: false
  name: ""  # Auto-populated when terraformConfig.enabled=true
  tenantId: ""  # Auto-populated when terraformConfig.enabled=true
```

## Pipeline Integration

The Azure DevOps pipeline automatically:

1. **Stage: Prepare_Terraform_Values** (runs after Setup_ArgoCD)
   - Initializes Terraform (if needed)
   - Reads Terraform outputs
   - Generates `chart/values-terraform.yaml`

2. **Stage: Build_and_Push**
   - Builds and pushes Docker image

3. **Stage: Update_Git_and_Trigger_Argo**
   - Updates image tag in `values.yaml`
   - Commits `values-terraform.yaml` (if generated)
   - ArgoCD syncs with both files

## Benefits

✅ **No Hardcoded Values**: Tenant ID and Key Vault name come from Terraform  
✅ **Single Source of Truth**: Terraform outputs drive Helm configuration  
✅ **Environment Agnostic**: Works across dev/staging/prod with different Terraform states  
✅ **Automated**: Pipeline handles the integration automatically  
✅ **Fallback Support**: Can still use manual values if needed  

## Troubleshooting

### Terraform Outputs Not Available

```bash
# Ensure Terraform has been applied
cd terraform
terraform init
terraform apply

# Verify outputs exist
terraform output
```

### Values File Not Generated

Check pipeline logs for the `Prepare_Terraform_Values` stage. Ensure:
- Terraform backend is configured
- Terraform state is accessible
- Required outputs exist

### Helm Using Wrong Values

Verify `terraformConfig.enabled: true` in the values file being used:

```bash
# Check generated values file
cat chart/values-terraform.yaml

# Verify Helm is using it
helm template nginx-bluegreen ./chart -f chart/values-terraform.yaml | grep client-id
```

## Migration from Manual Values

If you currently have hardcoded values in `values.yaml`:

1. Set `terraformConfig.enabled: true`
2. Remove hardcoded `serviceAccount.workloadIdentityClientId`, `keyVault.name`, `keyVault.tenantId`
3. Run the pipeline or script to generate `values-terraform.yaml`
4. Deploy with both values files

The templates automatically prefer Terraform values when `terraformConfig.enabled: true`.

