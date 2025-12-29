# ============================================================================
# Terraform / CI Service Principal (Non-Human Identity)
# ============================================================================
# This service principal already exists and was bootstrapped manually with:
# - Entra ID: Directory Reader
# - Azure RBAC: User Access Administrator (subscription scope)
#
# Terraform references it to grant production write access.
# ============================================================================

variable "terraform_sp_object_id" {
  description = "Object ID of the Terraform service principal"
  type        = string
}

data "azuread_service_principal" "terraform" {
  object_id = var.terraform_sp_object_id
}
