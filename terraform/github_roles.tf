# ---------------------------------------------------------------------------
# Common GitHub Actions IAM roles - one plan + one apply role per repo.
# These roles are identical in structure for every repo; per-repo permissions
# are attached as separate inline policies in repo_<name>_iam_roles.tf.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Plan role - trusted to main branch pushes and PRs targeting main.
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
# Apply role - trusted to main branch only.
#
# PRs get sub "repo:org/repo:pull_request" which does NOT match, so no
# PR workflow can trigger an apply regardless of what the workflow file says.
#
# Only the state backend baseline is attached here. Per-repo permissions live
# in repo_<name>_iam_roles.tf.
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

resource "aws_iam_role_policy" "github_actions_tf_apply_base" {
  for_each = local.github_repos
  name     = "state-backend"
  role     = aws_iam_role.github_actions_tf_apply[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
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
    }]
  })
}
