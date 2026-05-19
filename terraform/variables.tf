variable "aws_region" {
  description = "AWS region where Identity Center is deployed"
  type        = string
  default     = "ap-southeast-2"
}

variable "user_email" {
  description = "Email address for the Identity Center user (used as username)"
  type        = string
}

variable "user_first_name" {
  description = "First name for the Identity Center user"
  type        = string
}

variable "user_last_name" {
  description = "Last name / family name for the Identity Center user"
  type        = string
}

variable "session_duration_standard" {
  description = "Session duration for standard permission sets (ISO 8601)"
  type        = string
  default     = "PT8H"
}

variable "session_duration_billing" {
  description = "Session duration for the Billing permission set"
  type        = string
  default     = "PT4H"
}

variable "session_duration_infra_admin" {
  description = "Session duration for the InfraAdmin permission set - kept short as it is only assumed for infrastructure work"
  type        = string
  default     = "PT1H"
}

variable "monthly_budget_usd" {
  description = "Monthly spend budget threshold in USD - alerts fire at 80% actual and 100% forecasted"
  type        = number
  default     = 20
}

variable "cloudtrail_log_retention_days" {
  description = "How long to retain CloudTrail logs in S3 and CloudWatch Logs (days)"
  type        = number
  default     = 30
}

variable "github_org" {
  description = "GitHub organisation or username that owns the repositories using OIDC"
  type        = string
}

variable "tf_state_bucket" {
  description = "S3 bucket name used as the Terraform state backend"
  type        = string
}
