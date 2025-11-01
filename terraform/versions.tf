terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Backend configuration is provided via command-line flags in the pipeline
  # or via -backend-config flags during terraform init
  # Example:
  #   terraform init \
  #     -backend-config="resource_group_name=<rg-name>" \
  #     -backend-config="storage_account_name=<sa-name>" \
  #     -backend-config="container_name=<container-name>" \
  #     -backend-config="key=infra.tfstate" \
  #     -backend-config="access_key=<access-key>"
  #
  # The Azure DevOps pipeline (aks-infra.yml) uses TerraformTaskV2@2
  # which automatically handles backend configuration via pipeline variables.
}

