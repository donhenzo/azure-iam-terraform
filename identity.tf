# ============================================================================
# Entra ID Groups (Dynamic, Environment-Aware)
# ============================================================================
# This file creates security groups in Entra ID (Azure AD) for RBAC assignments.
# Groups are created dynamically based on the environment variable (dev/prod).
#
# Naming Convention: grp-{platform}-{environment}-{team}-{access_level}
# Example: grp-az-dev-backend-contrib, grp-az-prod-accounting-read
#
# Note: Group definitions come from locals.tf (local.group_definitions)

# ---------------------------------------------------------------------------
# Create Entra ID security groups using for_each
# ---------------------------------------------------------------------------
# This resource block creates one group for each entry in group_definitions
# The for_each converts the list to a map using group name as the key
resource "azuread_group" "iam_groups" {
  for_each = {
    # Convert list to map: "grp-az-dev-backend-contrib" => { name, description, ... }
    for g in local.group_definitions : g.name => g
  }

  # The display name shown in Entra ID portal
  display_name = each.value.name

  # Mark as a security group (not a Microsoft 365 group)
  security_enabled = true

  # Add description for better documentation in Azure portal
  description = each.value.description
}



