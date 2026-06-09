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
