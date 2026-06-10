# ---------------------------------------------------------------------------
# Repositories granted GitHub Actions CI access.
#
# Adding a new repo takes two steps:
#   1. Add an entry below (state bucket + whether we manage it).
#   2. Create a matching repo_<name>_iam_roles.tf for its specific policies.
# github_roles.tf needs no changes and it applies to every repo automatically.
# ---------------------------------------------------------------------------

locals {
  github_repos = {
    "aws-foundations" = {
      state_bucket        = var.foundations_state_bucket
      manage_state_bucket = false
    }
    "devops-profile-coffee-card-app-demo" = {
      state_bucket        = "terraform-state-${data.aws_caller_identity.current.account_id}-coffee-card-app-demo"
      manage_state_bucket = true
    }
  }
  repos_needing_state_bucket = {
    for repo, config in local.github_repos : repo => config if config.manage_state_bucket
  }
}

resource "aws_s3_bucket" "terraform_state" {
  for_each      = local.repos_needing_state_bucket
  bucket        = each.value.state_bucket
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  for_each = local.repos_needing_state_bucket
  bucket   = aws_s3_bucket.terraform_state[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  for_each = local.repos_needing_state_bucket
  bucket   = aws_s3_bucket.terraform_state[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}
