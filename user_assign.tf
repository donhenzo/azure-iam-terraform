# ============================================================================
# User-to-Group Assignments (Variable-Driven)
# ============================================================================
# Manages human user membership in Entra ID groups.
# RBAC is applied indirectly via group membership.
# ============================================================================

# ---------------------------------------------------------------------------
# Variable: user assignments
# ---------------------------------------------------------------------------
variable "user_assignments" {
  description = "Map of users to the groups they should belong to"
  type = map(object({
    user_principal_name = string
    groups              = list(string)
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Look up users by UPN
# ---------------------------------------------------------------------------
data "azuread_user" "users" {
  for_each            = var.user_assignments
  user_principal_name = each.value.user_principal_name
}

# ---------------------------------------------------------------------------
# Expand user → group relationships
# ---------------------------------------------------------------------------
locals {
  # Only allow assignments to groups that actually exist
  user_group_map = {
    for assignment in flatten([
      for user_key, user in var.user_assignments : [
        for group_name in user.groups : {
          key        = "${user_key}-${group_name}"
          user_id    = data.azuread_user.users[user_key].id
          group_name = group_name
        }
        # this helps to stop terraform from assigning groups in prod that do not exist. 
        if contains(keys(azuread_group.iam_groups), group_name)
      ]
    ]) : assignment.key => assignment
  }
}


# ---------------------------------------------------------------------------
# Assign users to groups
# ---------------------------------------------------------------------------
resource "azuread_group_member" "user_group_membership" {
  for_each = local.user_group_map

  group_object_id  = azuread_group.iam_groups[each.value.group_name].id
  member_object_id = each.value.user_id
}
