# How the Terraform-to-Helm Dynamic Configuration Works

## 🎯 The Problem We're Solving

**Before**: You had to manually copy values from Terraform outputs into `values.yaml`:
- Tenant ID from Azure
- Key Vault name
- Managed Identity Client ID

**Now**: These values flow automatically from Terraform → Pipeline → Helm → Kubernetes

---

## 📊 Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    STEP 1: Infrastructure Provisioning          │
│                    (Terraform Apply)                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────┐
        │   Terraform Creates Resources:      │
        │   • AKS Cluster                     │
        │   • Key Vault (name: northbayAksKV) │
        │   • Managed Identity                 │
        │   • (and outputs values)             │
        └─────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    STEP 2: Terraform Outputs                   │
│                    (Stored in Terraform State)                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
          ┌─────────▼─────────┐ ┌─────▼──────────────┐
          │ tenant_id          │ │ key_vault_name     │
          │ "abc-123-..."      │ │ "northbayAksKV"    │
          └────────────────────┘ └────────────────────┘
                    │
          ┌─────────▼───────────────────┐
          │ aks_workload_identity_      │
          │ client_id                    │
          │ "def-456-..."               │
          └─────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    STEP 3: Pipeline Stage                       │
│                    Prepare_Terraform_Values                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
          ┌─────────▼─────────┐ ┌─────▼──────────────┐
          │ terraform init    │ │ terraform output   │
          │ (connect to state)│ │ (read values)      │
          └───────────────────┘ └────────────────────┘
                              │
                              ▼
        ┌──────────────────────────────────────┐
        │  Generate: chart/values-terraform.yaml│
        │                                      │
        │  terraformConfig:                    │
        │    enabled: true                     │
        │    tenantId: "abc-123-..."          │
        │    keyVaultName: "northbayAksKV"   │
        │    workloadIdentityClientId:        │
        │      "def-456-..."                  │
        │                                      │
        │  keyVault:                          │
        │    enabled: true                     │
        │    name: "northbayAksKV"           │
        │    tenantId: "abc-123-..."          │
        └──────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    STEP 4: Helm Template Rendering              │
│                    (ArgoCD or Helm Install)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
          ┌─────────▼─────────┐ ┌─────▼──────────────┐
          │ Read values.yaml  │ │ Read values-       │
          │ (base config)     │ │ terraform.yaml     │
          │                   │ │ (Terraform values) │
          └───────────────────┘ └────────────────────┘
                              │
                              ▼
        ┌──────────────────────────────────────┐
        │  Helm Template Logic:                 │
        │                                      │
        │  IF terraformConfig.enabled == true: │
        │    USE terraformConfig.tenantId       │
        │    USE terraformConfig.keyVaultName   │
        │    USE terraformConfig.               │
        │      workloadIdentityClientId          │
        │  ELSE:                                │
        │    USE keyVault.tenantId             │
        │    USE serviceAccount.               │
        │      workloadIdentityClientId        │
        └──────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    STEP 5: Kubernetes Resources Created        │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
          ┌─────────▼─────────┐ ┌─────▼──────────────┐
          │ ServiceAccount     │ │ SecretProviderClass│
          │                    │ │                    │
          │ annotations:       │ │ parameters:        │
          │   azure.workload.  │ │   clientID:        │
          │   identity/        │ │     "def-456-..."  │
          │   client-id:       │ │   keyvaultName:     │
          │   "def-456-..."   │ │     "northbayAksKV" │
          │                    │ │   tenantId:         │
          └────────────────────┘ │     "abc-123-..."  │
                                 └────────────────────┘
```

---

## 🔍 Step-by-Step Detailed Explanation

### **STEP 1: Terraform Provisions Infrastructure**

When you run `terraform apply` (or via pipeline `aks-infra.yml`):

```hcl
# terraform/main.tf creates:
module "key_vault" {
  name = "northbayAksKeyVault"  # This becomes the Key Vault name
  ...
}

module "aks_cluster" {
  # Creates managed identity with client_id: "abc-123-def-456-..."
  ...
}

# terraform/outputs.tf exposes:
output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
  # Returns: "12345678-1234-1234-1234-123456789012"
}

output "key_vault_name" {
  value = module.key_vault.name
  # Returns: "northbayAksKeyVault"
}

output "aks_workload_identity_client_id" {
  value = module.aks_cluster.workload_identity_client_id
  # Returns: "87654321-4321-4321-4321-210987654321"
}
```

**Result**: Terraform state contains these three values.

---

### **STEP 2: Pipeline Reads Terraform Outputs**

In the pipeline stage `Prepare_Terraform_Values`:

```bash
# 1. Initialize Terraform (connect to backend state)
cd terraform
terraform init \
  -backend-config="resource_group_name=..." \
  -backend-config="storage_account_name=..." \
  ...

# 2. Read outputs from Terraform state
TENANT_ID=$(terraform output -raw tenant_id)
# TENANT_ID = "12345678-1234-1234-1234-123456789012"

KEY_VAULT_NAME=$(terraform output -raw key_vault_name)
# KEY_VAULT_NAME = "northbayAksKeyVault"

WORKLOAD_IDENTITY_CLIENT_ID=$(terraform output -raw aks_workload_identity_client_id)
# WORKLOAD_IDENTITY_CLIENT_ID = "87654321-4321-4321-4321-210987654321"

# 3. Generate values-terraform.yaml file
cat > ../chart/values-terraform.yaml <<EOF
terraformConfig:
  enabled: true
  tenantId: "$TENANT_ID"
  keyVaultName: "$KEY_VAULT_NAME"
  workloadIdentityClientId: "$WORKLOAD_IDENTITY_CLIENT_ID"

keyVault:
  enabled: true
  name: "$KEY_VAULT_NAME"
  tenantId: "$TENANT_ID"
EOF
```

**Result**: `chart/values-terraform.yaml` file created with real values.

---

### **STEP 3: Helm Templates Use Smart Logic**

When Helm renders templates, it checks which values to use:

#### **ServiceAccount Template Logic** (`serviceaccount.yaml`):

```yaml
{{- $clientId := "" }}
{{- if .Values.terraformConfig.enabled }}
  {{- $clientId = .Values.terraformConfig.workloadIdentityClientId }}
  # ✅ USE: terraformConfig.workloadIdentityClientId
  # Value: "87654321-4321-4321-4321-210987654321"
{{- else if .Values.serviceAccount.workloadIdentityClientId }}
  {{- $clientId = .Values.serviceAccount.workloadIdentityClientId }}
  # Fallback: Use manual value from values.yaml
{{- end }}
```

**Decision Flow**:
1. Check: Is `terraformConfig.enabled == true`? 
   - ✅ YES → Use `terraformConfig.workloadIdentityClientId`
   - ❌ NO → Check if `serviceAccount.workloadIdentityClientId` exists
     - ✅ YES → Use that
     - ❌ NO → `$clientId` stays empty (no annotation added)

#### **SecretProviderClass Template Logic** (`secretproviderclass.yaml`):

```yaml
{{- $clientId := "" }}
{{- $keyVaultName := "" }}
{{- $tenantId := "" }}

{{- if .Values.terraformConfig.enabled }}
  {{- $clientId = .Values.terraformConfig.workloadIdentityClientId }}
  {{- $keyVaultName = .Values.terraformConfig.keyVaultName }}
  {{- $tenantId = .Values.terraformConfig.tenantId }}
  # ✅ USE: All values from terraformConfig
{{- else }}
  {{- $clientId = .Values.serviceAccount.workloadIdentityClientId }}
  {{- $keyVaultName = .Values.keyVault.name }}
  {{- $tenantId = .Values.keyVault.tenantId }}
  # Fallback: Use manual values from values.yaml
{{- end }}
```

**Result**: Variables populated with Terraform values (when enabled).

---

### **STEP 4: Helm Renders Final YAML**

Helm merges `values.yaml` + `values-terraform.yaml` and renders templates:

#### **Generated ServiceAccount YAML**:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-sa
  annotations:
    azure.workload.identity/client-id: "87654321-4321-4321-4321-210987654321"
    azure.workload.identity/use: "true"
  # ↑ This client ID came from Terraform!
```

#### **Generated SecretProviderClass YAML**:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: nginx-bluegreen-kv
spec:
  provider: azure
  parameters:
    clientID: "87654321-4321-4321-4321-210987654321"    # ← From Terraform
    keyvaultName: "northbayAksKeyVault"                # ← From Terraform
    tenantId: "12345678-1234-1234-1234-123456789012"  # ← From Terraform
```

**Result**: Kubernetes resources with correct Azure configuration.

---

### **STEP 5: ArgoCD Deploys to Kubernetes**

ArgoCD syncs the generated manifests to AKS:

1. **ServiceAccount** is created with workload identity annotations
2. **SecretProviderClass** is created with Key Vault configuration
3. **Pods** using the ServiceAccount can now:
   - Authenticate to Azure using the managed identity
   - Mount secrets from Key Vault using Secrets Store CSI Driver

---

## 🎯 Value Priority Logic

The templates use a **priority system**:

```
Priority 1 (HIGHEST): terraformConfig.* (when enabled)
    ↓
Priority 2: Manual values in values.yaml
    ↓
Priority 3: Empty/default values (no configuration)
```

**Example Flow**:
```
terraformConfig.enabled = true
    ↓
Use: terraformConfig.workloadIdentityClientId
    ↓
✅ Annotation added to ServiceAccount
```

```
terraformConfig.enabled = false
    ↓
Check: serviceAccount.workloadIdentityClientId exists?
    ↓
YES → Use that value
NO → No annotation (workload identity disabled)
```

---

## 💡 Real-World Example

### Scenario: Deploying to Production

**Before** (Manual):
1. Run `terraform apply`
2. Run `terraform output -raw tenant_id` → copy value
3. Run `terraform output -raw key_vault_name` → copy value
4. Run `terraform output -raw aks_workload_identity_client_id` → copy value
5. Edit `values.yaml` → paste all three values
6. Commit and push
7. Deploy

**Now** (Automatic):
1. Run `terraform apply` ✅
2. Pipeline automatically reads outputs ✅
3. Pipeline generates `values-terraform.yaml` ✅
4. Helm uses Terraform values automatically ✅
5. Deploy ✅

**Zero manual copying needed!**

---

## 🔄 What Happens in Each Pipeline Run

### **First Time Setup**:
```
1. Infrastructure Pipeline (aks-infra.yml)
   └─> Creates AKS, Key Vault, Managed Identity
       └─> Terraform state stores outputs

2. Application Pipeline (app-deploy.yml)
   └─> Stage: Prepare_Terraform_Values
       └─> Reads Terraform outputs
       └─> Creates values-terraform.yaml
   └─> Stage: Build_and_Push
       └─> Builds Docker image
   └─> Stage: Update_Git_and_Trigger_Argo
       └─> Updates image tag
       └─> Commits values-terraform.yaml
   └─> ArgoCD syncs
       └─> Helm renders templates
       └─> Uses Terraform values
       └─> Creates Kubernetes resources
```

### **Subsequent Deployments**:
```
1. Application Pipeline (app-deploy.yml)
   └─> Stage: Prepare_Terraform_Values
       └─> Re-reads Terraform outputs (values may have changed!)
       └─> Updates values-terraform.yaml
   └─> ... rest of pipeline
```

**If infrastructure changes** (e.g., Key Vault renamed), Terraform outputs update automatically, and the next deployment picks up the new values!

---

## 🛡️ Fallback Mechanism

If Terraform outputs aren't available or `terraformConfig.enabled: false`:

```yaml
# values.yaml
terraformConfig:
  enabled: false  # ← Disabled

serviceAccount:
  workloadIdentityClientId: "manual-client-id"  # ← Used instead

keyVault:
  name: "manual-key-vault-name"
  tenantId: "manual-tenant-id"
```

The templates will use these manual values as fallback. **This ensures backward compatibility!**

---

## ✨ Key Benefits

1. **Single Source of Truth**: Terraform outputs are the authority
2. **No Manual Copying**: Pipeline handles everything
3. **Environment Agnostic**: Same code works for dev/staging/prod
4. **Always Fresh**: Every deployment reads latest Terraform state
5. **Backward Compatible**: Can still use manual values if needed

---

## 🧪 Testing Locally

You can test this without the pipeline:

```bash
# 1. Generate values file
cd scripts
./prepare-helm-values-from-terraform.sh

# 2. Deploy with Helm
cd ..
helm upgrade --install nginx-bluegreen ./chart \
  -f chart/values.yaml \
  -f chart/values-terraform.yaml

# 3. Verify ServiceAccount
kubectl get sa nginx-sa -o yaml | grep client-id
# Should show the client ID from Terraform!
```

---

This system ensures your Helm chart always uses the correct Azure resource names and IDs from your Terraform infrastructure, eliminating the possibility of misconfiguration or manual errors! 🎉

