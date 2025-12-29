# ============================================================================
# RBAC Assignments (Environment-Aware)
# ============================================================================
# Dynamically assigns roles to Entra ID groups and service principals
# based on environment (dev/prod). Supports subscription- and RG-level access.

data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "rbac" {
  for_each = {
    # Convert local.rbac_assignments list to map using a unique key
    for r in local.rbac_assignments :
    "${r.role}-${lookup(r, "group_name", lookup(r, "principal_id", "sp"))}" => r
  }

  # Determine principal_id based on whether this is a group or service principal
  # - If 'principal_id' field exists: Use it directly (service principal)
  # - If 'group_name' field exists: Look up the group's object_id (Entra ID group)
  principal_id = contains(keys(each.value), "principal_id") ? (
    # Service principal: Use the provided principal_id directly
    each.value.principal_id
    ) : (
    # Entra ID group: Look up the object_id from the created groups
    azuread_group.iam_groups[each.value.group_name].object_id
  )

  role_definition_name = each.value.role

  # Resolve scope: subscription-level or resource group
  scope = each.value.scope_type == "subscription" ? (
    data.azurerm_subscription.current.id
    ) : (
    each.value.rg_name == "rg-shared-helpdesk" ? azurerm_resource_group.shared_helpdesk[0].id
    : azurerm_resource_group.backend.id
  )
  # CRITICAL: Only skip AAD check for service principals, NOT for groups
  # This helped prevent the "UnmatchedPrincipalType" error
  # Check if this assignment has a principal_id field (indicating it's a service principal)
  skip_service_principal_aad_check = lookup(each.value, "principal_id", null) != null
}
