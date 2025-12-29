# ============================================================================
# Variables
# ============================================================================

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

variable "platform_prefix" {
  description = "Platform identifier (e.g. az for Azure)"
  type        = string
  default     = "az"
}

variable "azure_region" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}

variable "teams" {
  description = "Teams and their access levels"
  type        = map(list(string))
  default = {
    backend    = ["read", "contrib"]
    accounting = ["read"]
    helpdesk   = ["read", "contrib"]
  }
}