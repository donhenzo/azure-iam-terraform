# ============================================================================
# Local Values — Identity & Access Intent
# ============================================================================
# This file defines all group and RBAC configurations in a declarative way.
# These locals are consumed by identity.tf and rbac.tf.
#
# Design Philosophy:
# - Environment-specific groups: Different per workspace (dev vs prod)
# - Shared groups: Created once in dev workspace, used across all environments
# - RBAC intent: Defined here, resolved to actual Azure IDs in rbac.tf

locals {
  # ---------------------------------------------------------------------------
  # Entra ID Group Definitions
  # ---------------------------------------------------------------------------
  # Groups are split into backend (environment-specific) and shared (global)

  # Backend groups change based on environment variable
  # DEV: Creates contributor + reader groups (devs can deploy)
  # PROD: Creates ONLY reader group (no contributors, changes via CI/CD)
  backend_groups = var.environment == "dev" ? [
    # Dev environment: Full contributor access for developers
    {
      name        = "grp-${var.platform_prefix}-dev-backend-contrib"
      description = "Developers with contributor access to dev backend resources"
    },
    {
      name        = "grp-${var.platform_prefix}-dev-backend-read"
      description = "Read-only access to dev backend for QA and junior developers"
    }
    ] : [
    # Prod environment: Read-only access ONLY (enforces CI/CD deployments)
    {
      name        = "grp-${var.platform_prefix}-prod-backend-read"
      description = "Read-only access for troubleshooting in production (changes via CI/CD only)"
    }
  ]

  # Shared groups are environment-agnostic (not tied to dev/prod)
  # Only created in DEV workspace to avoid duplication
  # These groups represent enterprise-wide job functions
  shared_groups = var.environment == "dev" ? [
    # Accounting: Subscription-wide visibility for cost tracking
    {
      name        = "grp-${var.platform_prefix}-accounting-read"
      description = "Finance team with subscription-wide read access across all environments"
    },
    # Helpdesk: Manages shared infrastructure (NOT environment-specific)
    {
      name        = "grp-${var.platform_prefix}-helpdesk-contrib"
      description = "IT helpdesk team with contributor access to shared support tools"
    },
    {
      name        = "grp-${var.platform_prefix}-helpdesk-read"
      description = "IT helpdesk team with read-only access to shared support tools"
    }
  ] : [] # Empty list in prod workspace (shared groups already exist from dev)

  # Combine backend and shared groups for identity.tf to consume
  group_definitions = concat(local.backend_groups, local.shared_groups)

  # ---------------------------------------------------------------------------
  # RBAC Assignments (Intent Definition)
  # ---------------------------------------------------------------------------
  # These define WHO gets WHAT access to WHICH scope
  # Actual Azure resource IDs are resolved in rbac.tf using these intents

  # Backend RBAC: Environment-specific role assignments
  # Maps backend groups to their appropriate resource groups
  backend_rbac = var.environment == "dev" ? [
    # Dev contributors: Can deploy/modify resources in dev backend RG
    {
      group_name = "grp-${var.platform_prefix}-dev-backend-contrib"
      role       = "Contributor"
      scope_type = "resource_group"
      rg_name    = "rg-dev-backend" # Resolved to actual ID in rbac.tf
    },
    # Dev readers: Can view resources in dev backend RG
    {
      group_name = "grp-${var.platform_prefix}-dev-backend-read"
      role       = "Reader"
      scope_type = "resource_group"
      rg_name    = "rg-dev-backend"
    }
    ] : [
    # Prod readers: Can ONLY view resources (no modifications allowed)
    {
      group_name = "grp-${var.platform_prefix}-prod-backend-read"
      role       = "Reader"
      scope_type = "resource_group"
      rg_name    = "rg-prod-backend" # Resolved to actual ID in rbac.tf
    }
  ]

  # Shared RBAC: Enterprise-wide role assignments
  # Only created in DEV workspace to avoid duplication
  shared_rbac = var.environment == "dev" ? [
    # Accounting: Subscription-level Reader for cost visibility
    # This scope means they can see ALL resource groups (current and future)
    {
      group_name = "grp-${var.platform_prefix}-accounting-read"
      role       = "Reader"
      scope_type = "subscription" # Subscription-wide access (not RG-specific)
    },
    # Helpdesk contributors: Can manage shared support tools
    {
      group_name = "grp-${var.platform_prefix}-helpdesk-contrib"
      role       = "Contributor"
      scope_type = "resource_group"
      rg_name    = "rg-shared-helpdesk" # Resolved to actual ID in rbac.tf
    },
    # Helpdesk readers: Can view shared support tools
    {
      group_name = "grp-${var.platform_prefix}-helpdesk-read"
      role       = "Reader"
      scope_type = "resource_group"
      rg_name    = "rg-shared-helpdesk"
    }
  ] : []

  # Empty list in prod workspace (shared RBAC already exists from dev)
  # Automation RBAC for service principals
  # NOTE: Uses 'principal_id' field (not 'group_name') to distinguish from groups
  # This allows rbac.tf to conditionally set skip_service_principal_aad_check
  automation_rbac = var.environment == "prod" ? [
    {
      principal_id = data.azuread_service_principal.terraform.object_id
      role         = "Contributor"
      scope_type   = "resource_group"
      rg_name      = "rg-prod-backend"
    }

  ] : []

  # Combine all RBAC intents for rbac.tf to consume
  # If you enable automation_rbac, add it to this concat:
  # rbac_assignments = concat(local.backend_rbac, local.shared_rbac, local.automation_rbac)
  rbac_assignments = concat(
    local.backend_rbac,
    local.shared_rbac,
    local.automation_rbac # for using service principal automation
  )
}