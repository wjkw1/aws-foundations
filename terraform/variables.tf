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
