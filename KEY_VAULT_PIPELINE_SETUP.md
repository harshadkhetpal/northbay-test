# Key Vault → Azure DevOps Pipeline Integration Guide

This guide walks you through linking Azure Key Vault to Azure DevOps pipelines for secure secret management.

## Overview

The integration flow:
1. **Bootstrap Script** (`key-vault/secrets.sh`) creates Key Vault and seeds secrets
2. **Azure DevOps Variable Group** links to Key Vault
3. **Pipelines** automatically read secrets from the variable group

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Azure DevOps organization and project
- Appropriate permissions:
  - **Azure**: Contributor role or Key Vault access policies
  - **Azure DevOps**: Project Administrator or Variable Group permissions

## Step 1: Run Bootstrap Script

First, create the Key Vault and seed all required secrets:

```bash
# Make script executable
chmod +x key-vault/secrets.sh

# Run with default values
./key-vault/secrets.sh

# Or with custom values
RG_NAME=custom-rg SA_NAME=customsa KV_NAME=custom-kv ./key-vault/secrets.sh
```

This script creates:
- ✅ Resource Group
- ✅ Storage Account
- ✅ Storage Container
- ✅ Key Vault
- ✅ All required secrets

**Expected Output:**
```
✓ Resource group created: northbay-tfstate-rg
✓ Storage account created: northbaytfstate
✓ Storage container created: tfstate
✓ Key Vault created: kv-northbay
✓ All secrets created in Key Vault
```

## Step 2: Verify Setup

Verify that everything was created correctly:

```bash
./scripts/verify-keyvault-link.sh
```

This checks:
- ✅ Key Vault exists
- ✅ All secrets are present
- ✅ Storage account and container exist

## Step 3: Create Azure DevOps Variable Group

### 3.1 Navigate to Variable Groups

1. Open Azure DevOps portal
2. Go to your project
3. Navigate to **Pipelines** → **Library**
4. Click **+ Variable group**

### 3.2 Configure Variable Group

**Basic Settings:**
- **Name**: `global-variables` (must match pipeline variable group name)
- **Description**: "Terraform backend and infrastructure secrets from Key Vault"

**Key Vault Integration:**
1. ✅ Check **"Link secrets from an Azure Key Vault as variables"**
2. Click **Authorize** (first time only - grants Azure DevOps access)
3. Select **Azure subscription** (service connection)
4. Select **Key Vault**: `kv-northbay` (or your Key Vault name)

### 3.3 Link Secrets

Click **+ Add** next to each secret to link:

| Secret Name | Variable Name in Pipeline | Description |
|------------|---------------------------|-------------|
| `terraformBackendResourceGroupName` | `$(terraformBackendResourceGroupName)` | Terraform backend resource group |
| `terraformBackendStorageAccountName` | `$(terraformBackendStorageAccountName)` | Terraform backend storage account |
| `terraformBackendContainerName` | `$(terraformBackendContainerName)` | Terraform backend container |
| `terraformBackendStorageAccountKey` | `$(terraformBackendStorageAccountKey)` | Terraform backend storage account key |

**Important**: 
- Secret names in Key Vault must match exactly (case-sensitive)
- Variables are automatically available in pipelines that reference this variable group
- Variables are marked as **secret** (masked in logs)

### 3.4 Save Variable Group

Click **Save** to create the variable group.

## Step 4: Verify Pipeline Access

### 4.1 Check Service Connection

Ensure your Azure DevOps service connection has access to Key Vault:

1. Go to **Project Settings** → **Service connections**
2. Find your Azure subscription service connection
3. Verify it has **Key Vault Secrets User** role (automatically granted during authorization)

### 4.2 Test Variable Access (Optional)

Create a test pipeline to verify variables are accessible:

```yaml
trigger: none

variables:
- group: global-variables

pool:
  vmImage: ubuntu-latest

steps:
- bash: |
    echo "Testing variable access..."
    echo "RG: $(terraformBackendResourceGroupName)"
    echo "SA: $(terraformBackendStorageAccountName)"
    # Secrets are automatically masked in logs
    echo "Key exists: $([ -n '$(terraformBackendStorageAccountKey)' ] && echo 'YES' || echo 'NO')"
```

Run the test pipeline to verify variables load correctly.

## Step 5: Update Pipeline to Use Variable Group

Your pipelines (`aks-infra.yml`, `app-deploy.yml`) already reference the variable group:

```yaml
variables:
- group: global-variables  # ← This links to Key Vault

- task: TerraformTaskV2@2
  inputs:
    backendAzureRmResourceGroupName: $(terraformBackendResourceGroupName)  # ← From Key Vault
    backendAzureRmStorageAccountName: $(terraformBackendStorageAccountName)  # ← From Key Vault
    # ... etc
```

No pipeline code changes needed! The variables are automatically available.

## Troubleshooting

### Problem: "Variable group not found"

**Solution:**
- Ensure variable group name matches exactly: `global-variables`
- Check variable group is authorized for the pipeline
- Verify you have access to the variable group

### Problem: "Key Vault access denied"

**Solution:**
```bash
# Grant service principal access to Key Vault
az keyvault set-policy \
  --name kv-northbay \
  --spn <service-principal-id> \
  --secret-permissions get list
```

Or re-authorize in Azure DevOps (goes through OAuth flow automatically).

### Problem: "Secret not found in Key Vault"

**Solution:**
1. Verify secrets exist:
   ```bash
   az keyvault secret list --vault-name kv-northbay -o table
   ```

2. Re-run bootstrap script:
   ```bash
   ./key-vault/secrets.sh
   ```

3. Check secret names match exactly (case-sensitive)

### Problem: "Storage account not found"

**Solution:**
- Run bootstrap script to create storage account:
  ```bash
  ./key-vault/secrets.sh
  ```
- Verify storage account exists:
  ```bash
  az storage account show --name northbaytfstate --resource-group northbay-tfstate-rg
  ```

### Problem: Pipeline fails with "backend initialization error"

**Common causes:**
- Storage account doesn't exist
- Container doesn't exist
- Access key is incorrect
- Service principal doesn't have Storage Account Contributor role

**Solution:**
```bash
# Verify all backend resources exist
./scripts/verify-keyvault-link.sh

# Re-check variable group is linked correctly
# Re-run pipeline with verbose logging enabled
```

## Security Best Practices

1. **Key Vault Access Policies**
   - Use RBAC authorization mode (recommended)
   - Grant least-privilege access
   - Regularly audit access policies

2. **Variable Groups**
   - Use Key Vault linking (don't store secrets directly in variable groups)
   - Limit variable group access to required pipelines only
   - Enable variable group approval for production

3. **Service Connections**
   - Use managed identities when possible
   - Rotate service principal credentials regularly
   - Audit service connection usage

4. **Secret Rotation**
   - Rotate storage account keys periodically
   - Update Key Vault secrets when keys change
   - Pipelines automatically pick up new values on next run

## Verification Checklist

Before running production pipelines, verify:

- [ ] Key Vault created and accessible
- [ ] All 4 secrets exist in Key Vault
- [ ] Storage account and container exist
- [ ] Variable group `global-variables` created
- [ ] Variable group linked to Key Vault
- [ ] All secrets linked in variable group
- [ ] Service connection authorized for Key Vault access
- [ ] Test pipeline successfully reads variables
- [ ] Terraform pipeline can initialize backend

## Next Steps

Once Key Vault integration is complete:

1. **Run Infrastructure Pipeline**:
   - Execute `pipelines/aks-infra.yml`
   - Terraform will use backend from Key Vault variables

2. **Run Application Pipeline**:
   - Execute `pipelines/app-deploy.yml`
   - Application secrets can also be stored in Key Vault

3. **Monitor and Audit**:
   - Review Key Vault access logs
   - Monitor pipeline execution
   - Set up alerts for failed secret access

## Additional Resources

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure DevOps Variable Groups](https://docs.microsoft.com/azure/devops/pipelines/library/variable-groups)
- [Terraform Azure Backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html)

---

**Questions or Issues?**
- Run verification script: `./scripts/verify-keyvault-link.sh`
- Check Azure Key Vault logs in Azure Portal
- Review Azure DevOps pipeline logs for detailed error messages

