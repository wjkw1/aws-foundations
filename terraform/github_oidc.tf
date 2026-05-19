# ---------------------------------------------------------------------------
# GitHub Actions OIDC provider - account-level, only one exists per account.
# Other projects can reference the provider ARN from this repo's remote state
# or SSM rather than creating a duplicate.
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS auto-verifies this provider via OIDC discovery; thumbprints are a
  # fallback in case discovery is unavailable.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
}

# ---------------------------------------------------------------------------
# Plan role - one per repo, trusted to main branch pushes and PRs targeting main.
#
# The OIDC sub for a PR doesn't carry the target branch, so restricting
# to PRs-to-main is enforced by the workflow trigger (pull_request with
# branches: [main]), not here. The trust policy allows both subs because
# PRs are contributor-only (only you can open them).
# ---------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_tf_plan" {
  for_each    = local.github_repos
  name        = "github-actions-tf-plan-${each.key}"
  description = "GitHub Actions - terraform plan for ${each.key} on main branch and PRs targeting main"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${each.key}:ref:refs/heads/main",
            "repo:${var.github_org}/${each.key}:pull_request",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_tf_plan_readonly" {
  for_each   = local.github_repos
  role       = aws_iam_role.github_actions_tf_plan[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "github_actions_tf_plan_state" {
  for_each = local.github_repos
  name     = "state-backend-access"
  role     = aws_iam_role.github_actions_tf_plan[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "StateBackend"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",    # acquires the S3-native state lock
        "s3:DeleteObject", # releases the state lock
        "s3:ListBucket",
      ]
      Resource = [
        "arn:aws:s3:::${each.value.state_bucket}",
        "arn:aws:s3:::${each.value.state_bucket}/*",
      ]
    }]
  })
}

# ---------------------------------------------------------------------------
# Apply role - one per repo, trusted to main branch only.
#
# PRs get sub "repo:org/repo:pull_request" which does NOT match, so no
# PR workflow can trigger an apply regardless of what the workflow file says.
#
# NOTE: The policy statements below are scoped to what aws-foundations manages.
# When adding a new repo, attach a separate inline policy with only the
# permissions that repo's Terraform needs.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_tf_apply" {
  for_each    = local.github_repos
  name        = "github-actions-tf-apply-${each.key}"
  description = "GitHub Actions - terraform apply for ${each.key} on main branch only"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${each.key}:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_tf_apply" {
  for_each = local.github_repos
  name     = "tf-apply"
  role     = aws_iam_role.github_actions_tf_apply[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateBackend"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${each.value.state_bucket}",
          "arn:aws:s3:::${each.value.state_bucket}/*",
        ]
      },
      {
        Sid      = "IdentityCenter"
        Effect   = "Allow"
        Action   = ["sso-admin:*", "identitystore:*"]
        Resource = "*"
      },
      {
        # Scoped to only the IAM resource types this repo manages:
        # the CloudTrail delivery role and the GitHub OIDC provider.
        Sid    = "IAMFoundations"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
        ]
        Resource = "*"
      },
      {
        Sid      = "S3"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = "*"
      },
      {
        Sid      = "CloudTrail"
        Effect   = "Allow"
        Action   = ["cloudtrail:*"]
        Resource = "*"
      },
      {
        Sid    = "Observability"
        Effect = "Allow"
        Action = ["cloudwatch:*", "logs:*", "sns:*"]
        Resource = "*"
      },
      {
        Sid      = "Budgets"
        Effect   = "Allow"
        Action   = ["budgets:*"]
        Resource = "*"
      },
      {
        # SSO requires read access to the organization to enumerate accounts.
        Sid    = "OrgsRead"
        Effect = "Allow"
        Action = ["organizations:Describe*", "organizations:List*"]
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
