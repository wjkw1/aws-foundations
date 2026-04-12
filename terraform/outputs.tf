output "identity_center_user_id" {
  description = "Identity store user ID"
  value       = aws_identitystore_user.admin.user_id
}

output "sso_start_url" {
  description = "AWS access portal URL — bookmark this for day-to-day login"
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
