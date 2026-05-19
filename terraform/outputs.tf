output "identity_center_user_id" {
  description = "Identity store user ID"
  value       = aws_identitystore_user.admin.user_id
}

output "sso_start_url" {
  description = "AWS access portal URL - bookmark this for day-to-day login"
  value       = "https://${tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]}.awsapps.com/start"
}

output "permission_set_arns" {
  description = "ARNs of the four permission sets"
  value = {
    iam_admin           = aws_ssoadmin_permission_set.iam_admin.arn
    developer           = aws_ssoadmin_permission_set.developer.arn
    developer_read_only = aws_ssoadmin_permission_set.developer_read_only.arn
    billing             = aws_ssoadmin_permission_set.billing.arn
  }
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN - reference this in per-project IAM roles instead of creating a duplicate provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_arns" {
  description = "IAM role ARNs for GitHub Actions CI - plan allows main branch and PRs, apply is main branch only"
  value = {
    for key in keys(local.github_repos) : key => {
      plan  = aws_iam_role.github_actions_tf_plan[key].arn
      apply = aws_iam_role.github_actions_tf_apply[key].arn
    }
  }
}
