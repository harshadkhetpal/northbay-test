# Azure Workload Identity & Secrets Store CSI Driver Setup Guide

## Overview

This Helm chart is now configured to support:
1. **Azure Workload Identity** - Pods authenticate to Azure resources using managed identity (no secrets needed)
2. **Secrets Store CSI Driver** - Mount secrets from Azure Key Vault directly into pods

## Prerequisites

1. **AKS Cluster** with Workload Identity enabled (already configured in Terraform)
2. **Secrets Store CSI Driver** installed on the cluster
3. **Azure Key Vault** with secrets stored
4. **Managed Identity** with proper permissions to Key Vault

## Step 1: Install Secrets Store CSI Driver (if not already installed)

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true
```

## Step 2: Install Azure Key Vault Provider

```bash
helm repo add azure-workload-identity https://azure.github.io/azure-workload-identity/charts
helm install workload-identity-webhook azure-workload-identity/workload-identity-webhook \
  --namespace azure-workload-identity-system \
  --create-namespace
```

## Step 3: Create User-Assigned Managed Identity (if needed)

If you need a separate managed identity for your application (not the AKS cluster identity):

```bash
# Get resource group and location
RESOURCE_GROUP="northbayRG"  # Or your resource group name
LOCATION="eastus"  # Or your location

# Create managed identity
az identity create \
  --name nginx-workload-identity \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Get the client ID (you'll need this)
CLIENT_ID=$(az identity show \
  --name nginx-workload-identity \
  --resource-group $RESOURCE_GROUP \
  --query clientId -o tsv)

echo "Client ID: $CLIENT_ID"
```

## Step 4: Grant Key Vault Permissions

Grant the managed identity permissions to read secrets from Key Vault:

```bash
# Get Key Vault name
KEY_VAULT_NAME="northbayAksKeyVault"  # Or your Key Vault name
RESOURCE_GROUP="northbayRG"  # Or your resource group name

# Get managed identity principal ID (use AKS identity or your app identity)
# Option 1: Use AKS managed identity
PRINCIPAL_ID=$(az aks show \
  --name <your-aks-cluster-name> \
  --resource-group $RESOURCE_GROUP \
  --query identity.userAssignedIdentities -o json | jq -r '.[].principalId')

# Option 2: Use your app-specific managed identity
PRINCIPAL_ID=$(az identity show \
  --name nginx-workload-identity \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

# Grant Key Vault permissions
az keyvault set-policy \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list
```

If using RBAC on Key Vault:

```bash
# Assign Key Vault Secrets User role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope "/subscriptions/<subscription-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME"
```

## Step 5: Establish Federated Credential (OIDC)

Link the Kubernetes ServiceAccount to the Azure Managed Identity:

```bash
# Get AKS cluster details
AKS_NAME="northbayAks"  # Or your AKS cluster name
RESOURCE_GROUP="northbayRG"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get OIDC issuer URL
OIDC_ISSUER=$(az aks show \
  --name $AKS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create federated credential
az identity federated-credential create \
  --name nginx-federated-credential \
  --identity-name nginx-workload-identity \
  --resource-group $RESOURCE_GROUP \
  --issuer $OIDC_ISSUER \
  --subject system:serviceaccount:default:nginx-sa \
  --audience api://AzureADTokenExchange

# Note: Adjust namespace if your service account is in a different namespace
```

## Step 6: Update Helm values.yaml

Edit `chart/values.yaml`:

```yaml
serviceAccount:
  create: true
  name: nginx-sa
  workloadIdentityClientId: "YOUR_CLIENT_ID_HERE"  # From Step 3

keyVault:
  enabled: true
  name: "northbayAksKeyVault"  # Your Key Vault name
  tenantId: "YOUR_TENANT_ID"  # Get with: az account show --query tenantId -o tsv
  secrets:
    - secretName: "app-secrets"
      objects:
        - objectName: "database-password"  # Your secret name in Key Vault
          objectType: "secret"
          objectVersion: ""  # Leave empty for latest
        - objectName: "api-key"
          objectType: "secret"
```

## Step 7: Deploy the Chart

```bash
helm install nginx-bluegreen ./chart \
  --set serviceAccount.workloadIdentityClientId="<client-id>" \
  --set keyVault.enabled=true \
  --set keyVault.name="northbayAksKeyVault" \
  --set keyVault.tenantId="<tenant-id>"
```

## Step 8: Verify Secret Mounting

After deployment, verify secrets are mounted:

```bash
# Check pods are running
kubectl get pods

# Exec into a pod
kubectl exec -it <pod-name> -- sh

# List mounted secrets
ls -la /mnt/secrets-store/app-secrets/

# Read a secret (example)
cat /mnt/secrets-store/app-secrets/database-password
```

## Step 9: Access Secrets as Kubernetes Secrets (Optional)

The SecretProviderClass also creates Kubernetes secrets that you can reference in environment variables:

```yaml
env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: database-password
```

## Troubleshooting

### Pod fails to start with "mount failed"
- Verify Secrets Store CSI Driver is installed
- Check ServiceAccount has workload identity annotations
- Verify federated credential is created correctly

### "Access denied" when reading secrets
- Verify managed identity has Key Vault permissions
- Check OIDC issuer URL matches in federated credential
- Verify ServiceAccount name and namespace match federated credential subject

### Check logs
```bash
# Check CSI driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver

# Check workload identity webhook logs
kubectl logs -n azure-workload-identity-system -l app=azure-workload-identity-webhook
```

## Using AKS Cluster Managed Identity

If you want to use the AKS cluster's managed identity instead of a separate identity:

1. Get the client ID from Terraform output:
```bash
terraform output aks_identity_client_id
```

2. Use that client ID in `values.yaml`

3. Grant permissions to that identity instead

4. Create federated credential with that identity

## Security Best Practices

1. Use separate managed identities per application (principle of least privilege)
2. Grant only necessary Key Vault permissions (get, list for secrets)
3. Use specific secret versions in production (don't use latest)
4. Enable Key Vault RBAC for better access control
5. Regularly rotate secrets in Key Vault
6. Monitor Key Vault access logs

## Additional Resources

- [Azure Workload Identity Documentation](https://azure.github.io/azure-workload-identity/docs/)
- [Secrets Store CSI Driver Documentation](https://secrets-store-csi-driver.sigs.k8s.io/)
- [Azure Key Vault Provider](https://azure.github.io/secrets-store-csi-driver-provider-azure/)

