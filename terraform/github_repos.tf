# ---------------------------------------------------------------------------
# Repositories granted GitHub Actions CI access.
# Add an entry here to give a repo's workflows plan/apply permissions,
# then create a matching repo_<name>_iam_roles.tf for its specific policies.
# ---------------------------------------------------------------------------

locals {
  github_repos = {
    "aws-foundations" = { state_bucket = var.foundations_state_bucket }
    "devops-profile-coffee-card-app-demo" = {
      state_bucket = aws_s3_bucket.terraform_state["devops-profile-coffee-card-app-demo"].id
    }
  }
  repos_needing_state_bucket = {
    "devops-profile-coffee-card-app-demo" = {
      state_bucket = "terraform-state-${data.aws_caller_identity.current.account_id}-coffee-card-app-demo"
    }
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
