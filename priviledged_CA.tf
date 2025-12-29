# ============================================================================
# Conditional Access: Privileged Directory Roles
# ============================================================================
# Enforces stronger controls for users signing in with directory roles.
# Designed to work with PIM (requires Entra ID P2).
# Policy is staged (disabled) until licensing + PIM are enabled.
# ============================================================================

# Declare the break-glass account variable
variable "break_glass_object_id" {
  description = "Object ID of the break-glass account to exclude from privileged CA policies"
  type        = string
  default     = "" #break-glass user object Id
}

# Conditional Access policy for privileged roles
resource "azuread_conditional_access_policy" "privileged_directory_roles" {
  display_name = "CA-PRIVILEGED-DIRECTORY-ROLES"
  state        = "disabled" # Staged – requires Entra ID P2 + PIM

  conditions {
    client_app_types = [
      "browser",
      "mobileAppsAndDesktopClients"
    ]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]

      excluded_users = [
        var.break_glass_object_id,
        var.terraform_sp_object_id
      ]

      included_roles = [
        "62e90394-69f5-4237-9190-012177145e10", # Global Administrator
        "fe930be7-5e62-47db-91af-98c3a49a38b1", # Privileged Role Administrator
        "194ae4cb-b126-40b2-bd5b-6091b380977d", # Security Administrator
        "29232cdf-9323-42fd-ade2-1d097af3e4de"  # Exchange Administrator
      ]
    }
  }

  grant_controls {
    operator = "AND"
    built_in_controls = [
      "mfa"
    ]
  }

  session_controls {
    sign_in_frequency        = 1
    sign_in_frequency_period = "hours"
    persistent_browser_mode  = "never"
  }
}
