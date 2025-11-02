# ArgoCD Configuration

This directory contains ArgoCD configuration files for managing the Dubai Real Estate ML service deployment.

## Files Overview

### Core Application Configuration

- **`app-bluegreen.yaml`** - Main ArgoCD Application resource
  - Defines the Helm chart source and destination
  - Configures automated sync with retry logic
  - Includes health checks and finalizers

### Project Configuration

- **`project.yaml`** - ArgoCD AppProject resource
  - Defines allowed repositories and destinations
  - Configures RBAC roles and permissions
  - Sets up sync windows

### Repository Access

- **`repo-secret.yaml`** - Git repository credentials
  - SSH key for GitHub access
  - Alternative HTTPS configuration (commented)
  - **Important**: Replace placeholder SSH key with actual key or use Key Vault

### Configuration Patches

- **`patches/argocd-cm.yaml`** - ArgoCD ConfigMap patches
  - Server configuration
  - Dex SSO configuration
  - Resource exclusions

- **`patches/argocd-rbac-cm.yaml`** - RBAC policies
  - Role-based access control
  - Permission definitions
  - Group assignments

## Setup Instructions

### 1. Configure Git Repository Access

**Option A: SSH Key (Recommended)**
1. Generate SSH key:
   ```bash
   ssh-keygen -t ed25519 -C "argocd@northbay" -f argocd-key
   ```
2. Add public key to GitHub:
   - Go to GitHub Settings → SSH and GPG keys
   - Add new SSH key with contents of `argocd-key.pub`
3. Store private key in Azure Key Vault:
   ```bash
   az keyvault secret set \
     --vault-name kv-northbay \
     --name argocd-git-ssh-key \
     --file argocd-key
   ```
4. Update `repo-secret.yaml` to reference Key Vault secret

**Option B: HTTPS with Personal Access Token**
1. Generate GitHub personal access token with `repo` scope
2. Store in Key Vault:
   ```bash
   az keyvault secret set \
     --vault-name kv-northbay \
     --name github-token \
     --value <your-token>
   ```
3. Uncomment HTTPS configuration in `repo-secret.yaml`

### 2. Apply ArgoCD Configuration

The pipeline automatically applies these configurations during the `Setup_ArgoCD` stage:

```bash
# Manual application (if needed):
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/repo-secret.yaml
kubectl apply -f argocd/app-bluegreen.yaml
kubectl apply -f argocd/patches/argocd-cm.yaml
kubectl apply -f argocd/patches/argocd-rbac-cm.yaml
```

### 3. Verify ArgoCD Application

```bash
# Check application status
kubectl get applications -n argocd

# Get detailed status
kubectl describe application dubai-realestate-ml -n argocd

# View sync status
argocd app get dubai-realestate-ml
```

## RBAC Roles

The configuration includes the following roles:

- **`role:devops`** - Full access to all applications
- **`role:readonly`** - View-only access
- **`role:developer`** - Sync access to Dubai ML project only
- **`role:project-admin`** - Full access to specific project

To assign users to roles, update the `g, <user>, role:<role>` lines in `argocd-rbac-cm.yaml`.

## Sync Windows

Sync windows are configured in `project.yaml`:

- **Allow Window**: 24/7 with manual sync enabled
- **Deny Window**: Example maintenance window (commented out)

Adjust sync windows based on your deployment schedule.

## Health Checks

The application includes health checks for:
- Service availability
- Deployment status
- Pod readiness

Health status is displayed in ArgoCD UI and affects sync behavior.

## Troubleshooting

### Application stuck in "Syncing" state
```bash
# Check application events
kubectl get events -n argocd --field-selector involvedObject.name=dubai-realestate-ml

# Force sync
argocd app sync dubai-realestate-ml --force
```

### Repository access issues
```bash
# Test repository connectivity
argocd repo list
argocd repo test git@github.com:harshadkhetpal/northbay-test.git
```

### RBAC permission errors
```bash
# Check user permissions
argocd account can-i <action> <resource>
```

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Application Spec](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [ArgoCD RBAC](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)

