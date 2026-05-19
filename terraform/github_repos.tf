# ---------------------------------------------------------------------------
# Repositories granted GitHub Actions CI access.
# Add an entry here to give a repo's workflows plan/apply permissions.
# Each entry specifies the S3 bucket used as that repo's Terraform state backend.
# ---------------------------------------------------------------------------

locals {
  github_repos = {
    "aws-foundations" = { state_bucket = var.tf_state_bucket }
  }
}
