# ---------------------------------------------------------------------------
# Data - discover the Identity Center instance (there is only ever one)
# ---------------------------------------------------------------------------
data "aws_ssoadmin_instances" "main" {}
data "aws_caller_identity" "current" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]

  # Reusable deny statement blocks
  deny_billing_actions = [
    "aws-portal:*", # legacy console, kept for completeness
    "billing:*",
    "ce:*",
    "cur:*",
    "freetier:*",
    "invoicing:*",
    "payments:*",
    "purchase-orders:*",
    "tax:*",
  ]

  deny_iam_actions = [
    "iam:*",
    "organizations:*",
  ]
}

# ---------------------------------------------------------------------------
# Identity Center user
# ---------------------------------------------------------------------------
resource "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id

  display_name = "${var.user_first_name} ${var.user_last_name}"
  user_name    = var.user_email


  name {
    given_name  = var.user_first_name
    family_name = var.user_last_name
  }

  emails {
    value   = var.user_email
    type    = "work"
    primary = true
  }
}

# ===========================================================================
# Permission set: IamAdmin
# Policies : IAMFullAccess + ReadOnlyAccess
# Deny     : Billing
# ===========================================================================
resource "aws_ssoadmin_permission_set" "iam_admin" {
  name             = "IamAdmin"
  description      = "Full IAM control + read-only everywhere; billing access denied"
  instance_arn     = local.sso_instance_arn
  session_duration = var.session_duration_standard
}

resource "aws_ssoadmin_managed_policy_attachment" "iam_admin_iam_full" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.iam_admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_ssoadmin_managed_policy_attachment" "iam_admin_read_only" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.iam_admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"

  # Managed policy attachments on the same permission set must be sequential
  depends_on = [aws_ssoadmin_managed_policy_attachment.iam_admin_iam_full]
}

resource "aws_ssoadmin_permission_set_inline_policy" "iam_admin_deny" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.iam_admin.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyBilling"
        Effect   = "Deny"
        Action   = local.deny_billing_actions
        Resource = "*"
      },
    ]
  })
}

# ===========================================================================
# Permission set: Developer
# Policies : PowerUserAccess
# Deny     : IAM + Organizations + Billing
# ===========================================================================
resource "aws_ssoadmin_permission_set" "developer" {
  name             = "Developer"
  description      = "Power user; IAM, Organizations, and billing access denied"
  instance_arn     = local.sso_instance_arn
  session_duration = var.session_duration_standard
}

resource "aws_ssoadmin_managed_policy_attachment" "developer_power_user" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_ssoadmin_permission_set_inline_policy" "developer_deny" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyIAMAndOrgs"
        Effect   = "Deny"
        Action   = local.deny_iam_actions
        Resource = "*"
      },
      {
        Sid      = "DenyBilling"
        Effect   = "Deny"
        Action   = local.deny_billing_actions
        Resource = "*"
      },
    ]
  })
}

# ===========================================================================
# Permission set: DeveloperReadOnly
# Policies : ReadOnlyAccess
# Deny     : IAM + Organizations + Billing
# ===========================================================================
resource "aws_ssoadmin_permission_set" "developer_read_only" {
  name             = "DeveloperReadOnly"
  description      = "Read-only everywhere; IAM, Organizations, and billing denied"
  instance_arn     = local.sso_instance_arn
  session_duration = var.session_duration_standard
}

resource "aws_ssoadmin_managed_policy_attachment" "developer_read_only_policy" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer_read_only.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_ssoadmin_permission_set_inline_policy" "developer_read_only_deny" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer_read_only.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyIAMAndOrgs"
        Effect   = "Deny"
        Action   = local.deny_iam_actions
        Resource = "*"
      },
      {
        Sid      = "DenyBilling"
        Effect   = "Deny"
        Action   = local.deny_billing_actions
        Resource = "*"
      },
    ]
  })
}

# ===========================================================================
# Permission set: Billing
# Policies : Billing (job function) + Budgets Actions
# Deny     : none - this set is intentionally scoped to billing only
# ===========================================================================
resource "aws_ssoadmin_permission_set" "billing" {
  name             = "Billing"
  description      = "Billing, Cost Explorer, and Budgets management only"
  instance_arn     = local.sso_instance_arn
  session_duration = var.session_duration_billing
}

resource "aws_ssoadmin_managed_policy_attachment" "billing_job_function" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.billing.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/Billing"
}

resource "aws_ssoadmin_managed_policy_attachment" "billing_budgets_actions" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.billing.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AWSBudgetsActionsWithAWSResourceControlAccess"

  depends_on = [aws_ssoadmin_managed_policy_attachment.billing_job_function]
}

# ===========================================================================
# Permission set: InfraAdmin
# Policies : AdministratorAccess
# Deny     : Billing
# Use when : local Terraform runs or any elevated infrastructure work
# ===========================================================================
resource "aws_ssoadmin_permission_set" "infra_admin" {
  name             = "InfraAdmin"
  description      = "AdministratorAccess for infrastructure work; billing denied; short 1-hour session"
  instance_arn     = local.sso_instance_arn
  session_duration = var.session_duration_infra_admin
}

resource "aws_ssoadmin_managed_policy_attachment" "infra_admin_admin_access" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.infra_admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set_inline_policy" "infra_admin_deny" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.infra_admin.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyBilling"
        Effect   = "Deny"
        Action   = local.deny_billing_actions
        Resource = "*"
      },
    ]
  })
}

# ===========================================================================
# Account assignments - user → all five permission sets → your account
# ===========================================================================
locals {
  permission_sets = {
    iam_admin           = aws_ssoadmin_permission_set.iam_admin.arn
    developer           = aws_ssoadmin_permission_set.developer.arn
    developer_read_only = aws_ssoadmin_permission_set.developer_read_only.arn
    billing             = aws_ssoadmin_permission_set.billing.arn
    infra_admin         = aws_ssoadmin_permission_set.infra_admin.arn
  }
}

resource "aws_ssoadmin_account_assignment" "admin" {
  for_each = local.permission_sets

  instance_arn       = local.sso_instance_arn
  permission_set_arn = each.value

  principal_id   = aws_identitystore_user.admin.user_id
  principal_type = "USER"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}
