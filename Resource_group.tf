# ============================================================================
# Resource Groups (Environment-Aware)
# ============================================================================
# Creates resource groups based on the current workspace environment.
# - Dev workspace: Creates dev-backend + shared-helpdesk
# - Prod workspace: Creates prod-backend only (shared-helpdesk already exists)

# ---------------------------------------------------------------------------
# Backend Resource Group (Environment-Specific)
# ---------------------------------------------------------------------------
# Creates either dev or prod backend RG depending on environment variable
resource "azurerm_resource_group" "backend" {
  name     = "rg-${var.environment}-backend"
  location = var.azure_region

  tags = {
    Environment = title(var.environment) # "Dev" or "Prod"
    ManagedBy   = "Terraform"
    Purpose     = "${title(var.environment)} backend workloads"
    Workspace   = terraform.workspace
  }
}

# ---------------------------------------------------------------------------
# Shared Helpdesk Resource Group (Created Once)
# ---------------------------------------------------------------------------
# Only create in dev workspace to avoid duplication
# This RG is shared across all environments for IT support tools
resource "azurerm_resource_group" "shared_helpdesk" {
  count = var.environment == "dev" ? 1 : 0 # Only create in dev workspace

  name     = "rg-shared-helpdesk"
  location = var.azure_region

  tags = {
    Environment = "Shared"
    ManagedBy   = "Terraform"
    Purpose     = "IT helpdesk support tools (shared across all environments)"
    Workspace   = "dev" # Managed by dev workspace
  }
}