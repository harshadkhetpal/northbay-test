
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

* Automated provisioning pipeline (`pipelines/infra-pipeline.yml`)
* Application build and deploy pipeline (`pipelines/app-deploy.yml`)
* Secrets dynamically fetched from Azure Key Vault
* AKS deployments managed using Helm and ArgoCD with a GitOps workflow
* Supports Blue-Green deployment strategy with rollback capability

### Security Highlights

* Terraform remote backend securely stored in private Azure Storage Account
* Access keys managed in Azure Key Vault
* Azure DevOps linked securely with Key Vault via variable groups
* No credentials or secrets stored in YAML or Terraform code

Here’s the corrected and neatly formatted **README.md** section showing a clean and professional folder structure for your project:

```markdown
# 📁 Project Structure — northbay-test

```

northbay-test/
├── argocd/
│   ├── app-bluegreen.yaml
│   ├── argo-install.yaml
│   └── namespace.yaml
│
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment-blue.yaml
│       ├── deployment-green.yaml
│       ├── hpa.yaml
│       ├── ingress.yaml
│       ├── service.yaml
│       └── serviceaccount.yaml
│
├── key-vault/
│   └── secrets.sh
│
├── pipelines/
│   ├── aks-infra.yml
│   └── app-deploy.yml
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── tfvars/
│   │   └── stage.tfvars
│   └── modules/
│       ├── aks/
│       ├── container_registry/
│       ├── key_vault/
│       ├── log_analytics/
│       ├── node_pool/
│       ├── private_dns_zone/
│       ├── private_endpoint/
│       └── virtual_network/
│
└── README.md

```

---

### 🧩 Folder Summary

| Folder | Description |
|--------|--------------|
| **argocd/** | Contains ArgoCD manifests for GitOps-based deployment (blue/green strategy, installation, and namespace setup). |
| **chart/** | Helm chart directory with Kubernetes templates (Deployments, Services, Ingress, HPA, etc.) and configuration files. |
| **key-vault/** | Shell scripts and configurations for managing Azure Key Vault secrets. |
| **pipelines/** | Azure DevOps YAML pipeline definitions for infrastructure (`aks-infra.yml`) and application deployment (`app-deploy.yml`). |
| **terraform/** | IaC module defining AKS infrastructure — includes reusable modules, environment-specific `.tfvars`, and backend configuration. |
| **terraform/modules/** | Modular Terraform components such as AKS, VNet, Key Vault, Log Analytics, and Private Endpoints. |
| **README.md** | Documentation describing setup, structure, and usage guidelines for the project. |

---

Would you like me to also include a **setup section** (like `How to Deploy`, `Terraform Init`, `ArgoCD Sync`, and `Helm Install` commands) in this README so it looks production-grade and ready for GitHub?
```

## How It Works

### Step 1: Backend Initialization

* The script `key-vault/create-backend-secrets.sh` creates or updates a Key Vault and seeds secrets for Terraform backend configuration.
* Azure DevOps variable group links to the Key Vault to retrieve secrets securely during pipeline runs.

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

### 1. Create Backend Secrets

```bash
chmod +x key-vault/create-backend-secrets.sh
./key-vault/create-backend-secrets.sh
```

### 2. Link Key Vault to Azure DevOps

Navigate to Azure DevOps:

* Pipelines → Library → Variable Groups → New Group
* Enable: “Link secrets from an Azure Key Vault as variables”
* Select the Key Vault and link the following secrets:

  * terraformBackendResourceGroupName
  * terraformBackendStorageAccountName
  * terraformBackendContainerName
  * terraformBackendStorageAccountKey

### 3. Run Infrastructure Pipeline

Execute the pipeline:

* `pipelines/infra-pipeline.yml` provisions AKS, ACR, and Key Vault.

### 4. Run Application Deployment Pipeline

Execute the pipeline:

* `pipelines/app-deploy.yml` builds the Docker image and deploys it to AKS using Helm and ArgoCD.

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

