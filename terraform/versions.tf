terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend config is supplied at init time via backend.hcl (see bootstrap guide).
  # use_lockfile = true enables S3-native locking (Terraform >= 1.10) — no DynamoDB needed.
  # Terraform backend blocks don't support variable interpolation, so account-specific
  # values live in backend.hcl rather than being hardcoded here.
  backend "s3" {
    key          = "aws-foundations/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
