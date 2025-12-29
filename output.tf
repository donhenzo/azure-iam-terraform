# ============================================================================
# Outputs – IAM & RBAC Visibility
# ============================================================================

# ---------------------------------------------------------------------------
# Entra ID Groups
# ---------------------------------------------------------------------------
output "iam_groups" {
  description = "Entra ID groups created and managed by Terraform"
  value = {
    for name, grp in azuread_group.iam_groups :
    name => grp.object_id
  }
}

# ---------------------------------------------------------------------------
# Terraform / CI Service Principal
# ---------------------------------------------------------------------------
output "terraform_service_principal" {
  description = "Pre-created Terraform service principal"
  value = {
    object_id = data.azuread_service_principal.terraform.object_id
    client_id = data.azuread_service_principal.terraform.client_id
  }
}

# ---------------------------------------------------------------------------
# RBAC Assignments Summary
# ---------------------------------------------------------------------------
output "rbac_assignments" {
  description = "RBAC assignments applied via Terraform"
  value = {
    for key, r in azurerm_role_assignment.rbac :
    key => {
      role  = r.role_definition_name
      scope = r.scope
    }
  }
}
