# Azure IAM & RBAC with Terraform

**Enterprise-Grade Identity Governance Implemented as Code (IPGC-Driven)**

---

## 🎯 Project Overview

This project demonstrates production-ready Azure Identity and Access Management (IAM) implemented entirely with Terraform, using the **IPGC governance model:**

> **Intent → Policy → Governance → Control**

Rather than configuring access manually through the Azure Portal, all identity, RBAC, and Conditional Access decisions are defined **declaratively**.

This ensures access is:
- **Deliberate** - Every permission has a documented reason
- **Auditable** - Git history = access audit trail
- **Least-privileged** - Scoped to minimum required access
- **Consistently enforced** - No configuration drift

**IAM decisions are treated as security architecture, not operational afterthoughts.**

---

## Identity Governance Model — IPGC

This project is explicitly designed around **IPGC:**

### **Intent**
*Why* access exists, *who* needs it, and under *what constraints*.

### **Policy**
Formal rules that express intent (RBAC rules, Conditional Access policies).

### **Governance**
How access is managed, reviewed, changed, and revoked over time.

### **Control**
The technical enforcement mechanisms that make violations *impossible*.

**Every Terraform component in this repository maps to one or more layers of IPGC.**

---

## 1 INTENT — Access Design Philosophy

### Environment Intent

| Environment | Philosophy |
|-------------|-----------|
| **Development** | • Enable productivity with guardrails<br>• Humans may have standing access<br>• Contributor permissions are allowed<br>• Security controls protect identities, not velocity |
| **Production** | • Zero standing human write access<br>• Humans are read-only<br>• All deployments are automated<br>• Production safety overrides convenience |

### Identity Intent

- Users are never assigned roles directly** - All access flows through Entra ID security groups
- Identity lifecycle must be reversible, auditable, and centralized
- Automation identities are separated from human identities

### Security Intent

- Least privilege by default
- Blast radius must be limited by scope
- Environment separation must be enforced technically, not procedurally

---

## 2️ POLICY — Intent Expressed as Code

In this project, **policy is Terraform.**

### Core Access Policy Model
```
Identity (Entra ID Group) → Role (Azure RBAC) → Scope (RG / Subscription)
        WHO                      WHAT                  WHERE
```

All permissions are expressed through this chain.

---

##  Architecture Overview

### Current Implementation

| Resource Type          | Count |   Managed By |
|------------------------|-------|------------------|
| Entra ID Security Groups | 6 | Terraform (identity.tf) |
| Resource Groups          | 3 | Terraform (resources.tf) |
| RBAC Assignments         | 7 | Terraform (rbac.tf) |
| CA Policies |           1 (active) | Terraform (conditional-access.tf) |
| User Memberships | Variable | Terraform (user-assignments.tf) |

### File Structure & IPGC Mapping

| File |          IPGC Layer |           Purpose |
|------|-----------------------|---------------------|
| `locals.tf` | **Intent + Policy** | Defines *what* access exists and *why* |
| `identity.tf` | **Policy** | Creates identity objects (groups) |
| `rbac.tf` | **Control** | Enforces role assignments |
| `conditional-access.tf` | **Control** | Enforces authentication policies |
| `user-assignments.tf` | **Governance** | Manages user lifecycle |
| `variables.tf` | **Policy** | Tenant-agnostic configuration |
| `outputs.tf` | **Governance** | Provides audit trail |

---

## RBAC Policy Design

### Group Naming Convention

#### Environment-Specific Groups
Used when permissions differ by environment.

**Pattern:** `grp-{platform}-{environment}-{team}-{access}`

**Examples:**
- `grp-az-dev-backend-contrib` - Developers deploy to dev
- `grp-az-prod-backend-read` - Read-only prod access for troubleshooting

**Rationale:** Backend teams need different permissions per environment to enforce separation of duties.

#### Environment-Agnostic Groups
Used for enterprise-wide job functions.

**Pattern:** `grp-{platform}-{team}-{access}`

**Examples:**
- `grp-az-accounting-read` - Finance views all resources for cost tracking
- `grp-az-helpdesk-contrib` - IT manages shared infrastructure

**Rationale:** These job functions span all environments and don't belong to a specific one.

### Real-World Scenario
```
Scenario: New "staging" environment is created

Backend team:
  Create new group: grp-az-staging-backend-contrib
  
Accounting team:
  NO action needed - existing grp-az-accounting-read 
     already has subscription-wide access
  
Helpdesk team:
  NO action needed - they manage shared tools, 
     not environment-specific resources
```

---

### RBAC Mapping

| Group                      |     Role    |      Scope |    Environment |
|----------------------------|--------------|------------|---------------|
| `grp-az-dev-backend-contrib` | Contributor | `rg-dev-backend` | Dev |
| `grp-az-dev-backend-read` | Reader | `rg-dev-backend` | Dev |
| `grp-az-prod-backend-read` | Reader | `rg-prod-backend` | Prod |
| `grp-az-accounting-read` | Reader | Subscription | Shared |
| `grp-az-helpdesk-contrib` | Contributor | `rg-shared-helpdesk` | Shared |
| `grp-az-helpdesk-read` | Reader | `rg-shared-helpdesk` | Shared |
| **Terraform SP** | Contributor | `rg-prod-backend` | Automation |

### Scope Strategy (Policy Rationale)

**Resource Group scope for most teams**
→ Limits blast radius and prevents lateral impact

**Subscription Reader for accounting**
→ Enables cost visibility without write risk  
→ Avoids constant RBAC churn when new resource groups are created

**No subscription-level contributors**
→ Humans cannot affect resources outside their assigned scope

**Example:**
```
Scenario: New RG "rg-prod-analytics" is created tomorrow

RG-scoped: Would require manual RBAC update for accounting team
Subscription-scoped: Accounting automatically gains read access
```

---

## 3️⃣ GOVERNANCE — Managing Access Over Time

Governance ensures access remains **correct, minimal, and intentional** as the organization evolves.

### Identity Lifecycle Governance

User access is defined centrally via `terraform.tfvars`:

user_assignments = {
  alice = {
    user_principal_name = "alice@domain.com"
    groups = [
      "grp-az-dev-backend-contrib",
      "grp-az-helpdesk-read"
    ]
  }
  
  bob = {
    user_principal_name = "bob@domain.com"
    groups = [
      "grp-az-dev-backend-read"
    ]
  }
}


**Lifecycle automation:**
- **Add a user** → Terraform grants group access
- **Remove a user** → Terraform revokes all access
- **No manual cleanup**
- **No orphaned permissions**

This enforces **Join → Move → Leave** automatically.

### Change Governance

- **All IAM changes go through Terraform**
- **Git history = access audit trail**
- **No portal-only access modifications**
- **Changes are reviewable, reproducible, and reversible**

### Environment Governance

**Terraform Workspaces** enforce separation:

| Workspace | Purpose | State File |
|-----------|---------|-----------|
| `dev` | Development IAM + shared resources | `terraform.tfstate.d/dev/` |
| `prod` | Production IAM only | `terraform.tfstate.d/prod/` |

Each workspace has its own state file, preventing cross-environment drift.

#### Critical Rule

**Workspace must always match the environment variable.**
```bash
# CORRECT
terraform workspace select dev
terraform apply -var="environment=dev" ...

# WRONG (breaks governance guarantees)
terraform workspace select prod
terraform apply -var="environment=dev" ...
```

Violating this creates **state contamination** where prod state contains dev resources, leading Terraform to attempt destroying them.

### Governance Gap (Planned)

**Privileged Identity Management (PIM)** is planned to complete the governance layer:

- Just-in-time role activation
- Approval workflows
- Time-bound elevation
- Access reviews

This will govern **exceptional access**, not normal operations.

---

## 4️ CONTROL — Technical Enforcement

Controls are what make policy violations **technically impossible**.

### Identity Controls

- **Group-only RBAC assignments** - No user-to-role bindings
- **Correct handling of principal types** - Users ≠ Service Principals
- **Environment-aware group creation** - Prevents duplicate global groups

**Code example:**

shared_groups = var.environment == "dev" ? [...] : []


This single condition prevents:
- Duplicate tenant-wide groups
- Accidental prod privilege escalation

### Access Controls

- **Resource Group scoping** - Limits blast radius
- **Read-only human access in prod** - No standing write access
- **Automation identity scoped explicitly** - SP has minimum required permissions

### Authentication Controls (Conditional Access)

#### Implemented: CA-HUMAN-BASELINE-MFA

**Purpose:** Prevent account takeover of human users by enforcing modern authentication and MFA, while explicitly protecting automation.

**Applies to:**
- All human users (new users protected automatically)

**Excludes:**
- Service principals (cannot do MFA)
- Break-glass accounts (emergency access preserved)

**Enforces:**
- Multi-Factor Authentication
- Modern authentication only
- No persistent browser sessions
- Re-authentication every 2 days

**Blocks:**
- Password-only attacks
- Legacy protocol abuse (Basic Auth, old SMTP, POP3)
- Token replay from weak clients

#### Designed (Not Enforced Yet)

Fully coded but disabled due to licensing or tenant constraints:

**`legacy_auth_CA.tf`**  
→ Explicit legacy authentication blocking

**`privileged_CA.tf`**  
→ Stronger controls for privileged identities:
- MFA
- Short session lifetime
- No persistent sessions
- Device compliance (Intune-managed devices only)
- Corporate network only

**These files document policy intent, even when enforcement is not yet possible.**

---

## 🚀 Deployment Model

- **Terraform is the single source of truth**
- **CI/CD Service Principal performs all production changes**
- **Humans do not deploy to production**
- **No standing write access in prod**

### Service Principal Permissions

The Terraform service principal has **two** types of permissions:

#### Entra ID Roles (Identity Management)
- **Groups Administrator:** Create/manage groups and memberships
- **Directory Reader:** Read directory objects

az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" \
  --body '{
    "roleDefinitionId": "fdd7a751-b60b-444a-984c-02652fe8fa1c",
    "principalId": "<sp-object-id>",
    "directoryScopeId": "/"
  }'


#### Azure RBAC (Resource Management)
- **User Access Administrator (subscription):** Assign Azure roles
- **Contributor (rg-prod-backend):** Deploy resources to prod

az role assignment create \
  --assignee <sp-app-id> \
  --role "User Access Administrator" \
  --scope /subscriptions/<subscription-id>


### Security Model

| Actor | Dev Access | Prod Access | How |
|-------|------------|-------------|-----|
| **Developers** | Contributor | Reader | Via Entra ID groups |
| **CI/CD Pipeline** | N/A | Contributor | Via Terraform SP |
| **Accounting** | Reader (subscription) | Reader (subscription) | Via Entra ID group |
| **Helpdesk** | Contributor (shared tools) | No access | Via Entra ID groups |

---

## Quick Start

### Prerequisites

- Azure subscription with Owner or User Access Administrator role
- Azure CLI installed
- Terraform >= 1.6.0
- Service Principal with required permissions (see above)

### Initial Setup

1. **Clone the repository**

   git clone <repository-url>
   cd terraform-azure-IAM


2. **Configure Service Principal credentials**

   export ARM_CLIENT_ID="<your-sp-app-id>"
   export ARM_CLIENT_SECRET="<your-sp-secret>"
   export ARM_TENANT_ID="<your-tenant-id>"
   export ARM_SUBSCRIPTION_ID="<your-subscription-id>"


3. **Initialize Terraform**

   terraform init


4. **Deploy Dev Environment**

   terraform workspace new dev
   terraform apply \
     -var="environment=dev" \
     -var="terraform_sp_object_id=<your-sp-object-id>"


5. **Deploy Prod Environment**

   terraform workspace new prod
   terraform apply \
     -var="environment=prod" \
     -var="terraform_sp_object_id=<your-sp-object-id>"


### User Management

Edit `terraform.tfvars` to manage user access:

user_assignments = {
  "new_user" = {
    user_principal_name = "newuser@domain.com"
    groups = [
      "grp-az-dev-backend-contrib"
    ]
  }
}


Then apply:

terraform workspace select dev
terraform apply -var="environment=dev" -var="terraform_sp_object_id=<sp-id>"


---

## Lessons Learned

### 1. Identity Governance Is Logic, Not Objects

shared_groups = var.environment == "dev" ? [...] : []


This single condition prevents:
- Duplicate tenant-wide groups
- Accidental prod privilege escalation

**Lesson:** I didn't say "create these 6 groups." I said "for this environment, these identities exist and have these permissions." That is a  shift from **objects → intent**. 

### 2. Tenant-Wide vs Environment-Scoped Resources

•	Groups, Resource Groups, RBAC → environment-specific
•	Conditional Access → tenant-wide (created once)
Mixing these incorrectly creates hidden privilege paths.

**Why:** CA policies apply to the entire Azure AD tenant. Creating them in both workspaces causes duplication errors.

Mixing these incorrectly creates **hidden privilege paths**.

### 3. RBAC Correctness Matters

Azure strictly validates principal types:
- Groups ≠ Service Principals
- Terraform must reflect this explicitly

**Error encountered:**

Error: UnmatchedPrincipalType - The PrincipalId has type 'Group', 
which is different from specified PrincipalType 'ServicePrincipal'


**Fix:** Conditionally set `skip_service_principal_aad_check` based on principal type:

skip_service_principal_aad_check = contains(keys(each.value), "principal_id")


**Lesson:** Misalignment causes silent failures or insecure workarounds.

### 4. Workspace State Contamination

**Problem:** Accidentally ran `terraform apply -var="environment=dev"` in prod workspace.

**Result:** Prod state file contained dev resources. Terraform then wanted to destroy them.

**Fix:** Remove contaminated resources from state:

terraform workspace select prod
terraform state rm 'azuread_group.iam_groups["grp-az-dev-backend-contrib"]'
`

**Prevention:** Always verify workspace before applying:

terraform workspace show  # Check current workspace

### 5. Terraform Pattern Evolution

**Before (Individual Resources):**

resource "azuread_group" "dev_backend_contrib" { ... }
resource "azuread_group" "dev_backend_read" { ... }


**After (Dynamic for_each):**

resource "azuread_group" "iam_groups" {
  for_each = { for g in local.group_definitions : g.name => g }

}


**Benefits:**
- Reduced code duplication
- Easier to scale (add new teams/environments)
- Consistent naming across environments

---

## Future Enhancements

|Feature	Status
Privileged Identity Management (PIM)	Planned
Azure Bastion	Planned
Strict Production Conditional Access	Planned
Device Compliance Enforcement       	Planned
Defender for Cloud                  	Planned

### Planned: Privileged Identity Management (PIM)

**Purpose:** Just-in-time privileged access to production

**Benefits:**
- No standing admin access to prod
- Time-limited access (auto-revoke after 8 hours)
- Approval workflow for activation
- Full audit trail


## Final Statement

This project demonstrates **Azure IAM implemented using the IPGC governance model**, where:

- **Intent** defines *why* access exists
- **Policy** encodes intent declaratively
- **Governance** manages access over time
- **Control** enforces security technically

**IAM is treated as security architecture, not portal configuration.**

---

## License

This project is for educational and portfolio purposes.

---


















{"Donhenz}