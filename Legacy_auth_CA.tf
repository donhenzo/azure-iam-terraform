# ============================================================================
# Conditional Access: Block Legacy Authentication
# ============================================================================
resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "CA-BLOCK-LEGACY-AUTH"
  state        = "enabled"

  conditions {
    users {
      included_users = ["All"]
      excluded_users = [
        "" # this excludes my break-glass account
      ]
   }

    applications {
      included_applications = ["All"]
    }

    # Legacy authentication client types
    client_app_types = [
      "exchangeActiveSync",
      "other" # basic auth, POP, IMAP, SMTP AUTH, older protocols
    ]
  }

  grant_controls {
    operator = "OR"
    built_in_controls = [
      "block"
    ]
  }
}
