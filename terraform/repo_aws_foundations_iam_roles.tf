# ---------------------------------------------------------------------------
# aws-foundations: repo-specific IAM permissions
#
# tf-apply role permissions — manages IAM, OIDC, SSO/Identity Center,
# CloudTrail, observability, and budgets for this account.
# ---------------------------------------------------------------------------

resource "aws_iam_role_policy" "aws_foundations_tf_apply" {
  name = "foundations-permissions"
  role = aws_iam_role.github_actions_tf_apply["aws-foundations"].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "IdentityCenter"
        Effect   = "Allow"
        Action   = ["sso:*", "identitystore:*"]
        Resource = "*"
      },
      {
        Sid    = "IAMFoundations"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
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
          "iam:ListInstanceProfilesForRole",
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
        Sid      = "Observability"
        Effect   = "Allow"
        Action   = ["cloudwatch:*", "logs:*", "sns:*"]
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
        Sid      = "OrgsRead"
        Effect   = "Allow"
        Action   = ["organizations:Describe*", "organizations:List*"]
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
