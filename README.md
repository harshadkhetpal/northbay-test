
# NorthBay Secure AKS Infrastructure Deployment (Terraform + Azure DevOps)

## Project Overview

This project provisions a fully private and secure Azure Kubernetes Service (AKS) environment using Terraform for Infrastructure as Code (IaC) and Azure DevOps for automated CI/CD.
It demonstrates a production-grade deployment pipeline aligned with modern enterprise DevOps best practices.

---

## Architecture Summary

### Core Components

| Component                      | Purpose                                                                          |
| ------------------------------ | -------------------------------------------------------------------------------- |
| AKS (Private Cluster)          | Hosts application workloads securely inside Azure VNet with no public exposure.  |
| Azure Container Registry (ACR) | Stores and manages container images; accessed privately via Private Endpoint.    |
| Azure Key Vault                | Manages sensitive credentials, backend storage keys, and CI/CD secrets securely. |
| Azure Log Analytics            | Centralized monitoring and diagnostics for AKS and other resources.              |
| Azure DevOps Pipelines         | Automates provisioning (Terraform) and deployment (Helm + ArgoCD).               |

---

## Architecture Diagram

```
Azure VNet (eastus)
│
├── Subnets
│   ├── AKS Node Pool Subnet
│   ├── ACR Private Endpoint
│   └── Key Vault Private Endpoint
│
├── AKS (Private)
│   └── Connected to ACR & Key Vault privately
│
├── ACR (Private Link)
├── Key Vault (Private Link)
└── Log Analytics Workspace
```

All communication is private and isolated within Azure using Private Link and VNet integration.

---

## Key Features

### Infrastructure

* Modular Terraform codebase
* Private AKS cluster with Azure AD and RBAC integration
* Private ACR and Key Vault using Private DNS Zones and Private Endpoints
* Role-based access with least privilege (Network Contributor, AcrPull)
* Centralized logging through Log Analytics Workspace

### CI/CD Pipeline (Azure DevOps)

* Automated provisioning pipeline (`pipelines/aks-infra.yml`)
* Application build and deploy pipeline (`pipelines/app-deploy.yml`)
* Secrets dynamically fetched from Azure Key Vault via variable groups
* AKS deployments managed using Helm and ArgoCD with a GitOps workflow
* Supports Blue-Green deployment strategy with rollback capability
* Dubai Real Estate ML service deployment (FastAPI-based)

### Security Highlights

* Terraform remote backend securely stored in private Azure Storage Account
* Access keys managed in Azure Key Vault
* Azure DevOps linked securely with Key Vault via variable groups
* No credentials or secrets stored in YAML or Terraform code

## How It Works

### Step 1: Backend Initialization

* The enhanced script `key-vault/secrets.sh` creates the complete Terraform backend infrastructure:
  * Resource Group, Storage Account, Storage Container
  * Key Vault with all required secrets
  * Idempotent - safe to run multiple times
* Azure DevOps variable group (`global-variables`) links to Key Vault to retrieve secrets securely during pipeline runs.
* See [`KEY_VAULT_PIPELINE_SETUP.md`](KEY_VAULT_PIPELINE_SETUP.md) for detailed integration steps.

### Step 2: Terraform Infrastructure Pipeline

* Installs Terraform and authenticates using the Azure DevOps service connection.
* Fetches backend configuration from Key Vault-linked variables.
* Runs Terraform `init`, `plan`, and `apply` to provision AKS, ACR, and Key Vault resources privately.

### Step 3: Application Deployment

* Docker image is built and pushed to the private ACR.
* Helm chart deploys the application on AKS.
* ArgoCD manages GitOps-based continuous deployment with versioned rollbacks.

---

## Deployment Steps

### Prerequisites

* Azure CLI installed and authenticated (`az login`)
* Azure DevOps organization and project
* Appropriate Azure permissions (Contributor role or Key Vault access)
* Azure DevOps permissions (Project Administrator or Variable Group access)

### 1. Bootstrap Terraform Backend Infrastructure

Run the enhanced bootstrap script to create all required resources:

```bash
# Make script executable
chmod +x key-vault/secrets.sh

# Run with default values
./key-vault/secrets.sh

# Or with custom values
RG_NAME=custom-rg SA_NAME=customsa KV_NAME=custom-kv ./key-vault/secrets.sh
```

This script automatically creates:
* ✅ Resource Group (`northbay-tfstate-rg`)
* ✅ Storage Account (`northbaytfstate`)
* ✅ Storage Container (`tfstate`)
* ✅ Key Vault (`kv-northbay`)
* ✅ All required secrets in Key Vault

**Verify the setup:**
```bash
./scripts/verify-keyvault-link.sh
```

### 2. Link Key Vault to Azure DevOps

📖 **Detailed instructions:** See [`KEY_VAULT_PIPELINE_SETUP.md`](KEY_VAULT_PIPELINE_SETUP.md)

**Quick Steps:**
1. Navigate to Azure DevOps → **Pipelines** → **Library**
2. Create or edit variable group: **`global-variables`**
3. Enable **"Link secrets from an Azure Key Vault as variables"**
4. Select Key Vault: `kv-northbay` (or your Key Vault name)
5. Link these secrets:
   * `terraformBackendResourceGroupName`
   * `terraformBackendStorageAccountName`
   * `terraformBackendContainerName`
   * `terraformBackendStorageAccountKey`
6. Save the variable group

### 3. Run Infrastructure Pipeline

Execute the Terraform pipeline to provision infrastructure:

* **Pipeline**: `pipelines/aks-infra.yml`
* **What it does**:
  * Provisions private AKS cluster
  * Creates private ACR with Private Endpoint
  * Creates Key Vault with Private Endpoint
  * Sets up networking and security configurations

### 4. Run Application Deployment Pipeline

Execute the application pipeline to build and deploy:

* **Pipeline**: `pipelines/app-deploy.yml`
* **What it does**:
  * Builds Docker image for Dubai Real Estate ML service
  * Pushes to private ACR
  * Generates Helm values from Terraform outputs
  * Deploys to AKS using ArgoCD (GitOps)
  * Implements Blue-Green deployment strategy

---

## Future Scope

| Area                    | Enhancement                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------- |
| Networking              | Extend to hub-spoke topology with centralized Azure Firewall and UDR.                   |
| Observability           | Integrate Azure Monitor and Application Insights dashboards.                            |
| Security                | Enable Key Vault Managed HSM and stricter RBAC segmentation.                            |
| Automation              | Add Terraform-based provisioning of self-hosted Azure DevOps agents.                    |
| Multi-Environment CI/CD | Extend pipelines to manage Dev, QA, and Prod environments via environment-based tfvars. |

⚙️ ConfigMap

A separate ConfigMap is not required unless your application itself needs runtime configuration (e.g., environment variables, app settings, URLs).
Helm automatically handles values through values.yaml, which functions like a built-in ConfigMap for templating.

If your NGINX or app doesn’t load external configuration files, you can safely skip a standalone configmap.yaml.

## Objectives and Learnings

* Demonstrated complete Infrastructure-as-Code (IaC) lifecycle using Terraform.
* Built a secure Azure environment with private connectivity and role-based access control.
* Automated deployment pipelines using Azure DevOps, Helm, and ArgoCD.
* Implemented enterprise-grade architecture patterns with security and compliance focus.

---

## Author

**Harshad Khetpal**
Senior DevOps | Cloud | MLOps Engineer
Specializing in designing automated, secure, and scalable cloud environments on Azure and AWS.

