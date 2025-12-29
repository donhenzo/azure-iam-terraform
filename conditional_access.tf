# Conditional Access: Require MFA for all human users
resource "azuread_conditional_access_policy" "human_baseline_mfa" {
  display_name = "CA-HUMAN-BASELINE-MFA"
  state        = "enabled"

  conditions {
    users {
      included_users = ["All"] # Apply to all users
      excluded_users = [
        "" # Break-glass admin account
      ]
    }

    applications {
      included_applications = ["All"] # Apply to all apps
    }

    client_app_types = [
      "browser",                    # Web browsers
      "mobileAppsAndDesktopClients" # Mobile apps and desktop clients
    ]
  }

  grant_controls {
    operator = "AND" # All controls must be satisfied
    built_in_controls = [
      "mfa" # Require multi-factor authentication
    ]
  }
  session_controls {
    sign_in_frequency        = 2       # Require re-auth after N periods
    sign_in_frequency_period = "days"  # "hours" or "days"
    persistent_browser_mode  = "never" # "always", "never", or omit
  }
}