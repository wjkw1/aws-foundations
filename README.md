# AWS Foundations

This repository sets up the foundations for an AWS account.

It uses Terraform to manage the security, billing, identity, and access setup — giving you repeatability when you need to securely set up an AWS account.

## Contents

- [What Terraform configures](#what-terraform-configures)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Day to day after bootstrap](#day-to-day-after-bootstrap)
- [Granting a new repo GitHub Actions CI access](#granting-a-new-repo-github-actions-ci-access)
- [Troubleshooting](#troubleshooting)

## What Terraform configures

### Identity & access (`identity_center.tf`)

- **Identity Center user** - your SSO login
- **Account assignments** - all five sets bound to your account
- **Permission sets** - IamAdmin, Developer, DeveloperReadOnly, Billing, InfraAdmin (all scoped with deny policies to reduce blast radius)

  | Set               | Based on                       | Denies             | Session | Use when                                     |
  | ----------------- | ------------------------------ | ------------------ | ------- | -------------------------------------------- |
  | IamAdmin          | IAMFullAccess + ReadOnlyAccess | Billing            | 8h      | Managing users, roles, and policies          |
  | Developer         | PowerUserAccess                | IAM, Orgs, Billing | 8h      | Day-to-day AWS building                      |
  | DeveloperReadOnly | ReadOnlyAccess                 | IAM, Orgs, Billing | 8h      | Auditing / investigating without risk        |
  | Billing           | Billing + Budgets              | nothing            | 4h      | Checking costs and managing budgets          |
  | InfraAdmin        | AdministratorAccess            | Billing            | 1h      | Local Terraform runs and elevated infra work |

### Security baseline (`security.tf`)

- **S3 account public access block** - prevents any bucket in the account from being made public by default
- **CloudTrail** - multi-region audit trail of every API call; logs stored in a dedicated S3 bucket with 90-day retention and file integrity validation enabled
- **CloudWatch Logs + root account alarm** - CloudTrail streams to a log group; a metric filter fires an SNS alert the moment the root user is used
- **SNS security-alerts topic** - email subscription to `user_email`; delivers root alarm notifications
- **AWS Budget** - monthly spend budget with alerts at 80% actual and 100% forecasted, sent to `user_email`

> **After first `terraform apply`:** AWS will send a subscription confirmation email to your `user_email`. You must click the confirmation link before the root account alarm and budget alerts will actually deliver.

## Prerequisites

Install using Homebrew or your preferred package manager:

- [Terraform CLI](https://developer.hashicorp.com/terraform/install)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Getting started

Secure root, use the AWS CLI to create the S3 backend, then use Terraform to provision the IAM permission sets.

> Note: The Amazon S3 backend gives us encryption at rest and easy lockfile config. Lock files are innate now and no longer require dynamoDB.

### 1. Securing the `root` account

Do this before touching Terraform. The root account is the one thing you can never recover via code.

- Log in at aws.amazon.com with your root email
- Go to **IAM → Security credentials**
- Enable **MFA** (use an authenticator app)
- Do not create root access keys ever

### 2. Enable identity center (manual - console only)

Terraform cannot enable this for you. This lets you use AWS SSO logins once Terraform applies the infrastructure.

1. Go to **AWS IAM Identity Center → Enable**
2. Leave all settings default for now

### 3. Create a temporary bootstrap IAM user

This is a short-lived admin account just to run Terraform the first time.

- Go to **IAM → Users → Create user**
- Username: `terraform` (or whatever you want)
- Uncheck "Provide console access" (CLI only)
- Permissions: Attach `AdministratorAccess` directly
- After creation: **Security credentials → Create access key**
  - Use case: CLI
  - Save the Key ID and Secret - you only see the secret once, so make sure to copy it

### 4. Configure AWS CLI locally

```zsh
aws configure --profile terraform
# Key ID, Secret, region: ap-southeast-2, output: json

# Verify it works
aws sts get-caller-identity --profile terraform

# Set that profile for your terminal session:
export AWS_PROFILE=terraform
```

### 5. Prepare terraform config files

```zsh
cd terraform

# Copy examples and fill in your values
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars

```

**backend.hcl** - your S3 state bucket name:

```hcl
bucket = "tfstate-<account-id>-aws-foundations"
```

> Get your account ID: `aws sts get-caller-identity --query Account --output text`

**terraform.tfvars** - your Identity Center user details:

```hcl
user_email      = "you@example.com"
user_first_name = "First"
user_last_name  = "Last"
```

### 6. Create the s3 backend

Terraform needs this bucket to exist before `terraform init`.

Create it manually via the console or with the script below. Either way, ensure the bucket has:

- Name: must match what you put in `backend.hcl`
- Region: `ap-southeast-2`
- Enable **Versioning**
- Enable **Server-side encryption** (SSE-S3 is fine)
- Block all public access: on

```zsh
export AWS_BUCKET="tfstate-$(aws sts get-caller-identity --query Account --output text)-aws-foundations"
export AWS_REGION="ap-southeast-2"

# Create bucket (ap-southeast-2 requires LocationConstraint)
aws s3api create-bucket \
  --bucket "$AWS_BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"


# Versioning (allows state file recovery)
aws s3api put-bucket-versioning \
  --bucket "$AWS_BUCKET" \
  --versioning-configuration Status=Enabled

# Encryption at rest
aws s3api put-bucket-encryption \
  --bucket "$AWS_BUCKET" \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# Block all public access
aws s3api put-public-access-block \
  --bucket "$AWS_BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Bucket name: $AWS_BUCKET"
```

### 7. Run terraform

Initialise your terraform setup

```zsh
cd terraform

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### 8. Switch to SSO (and delete the IAM user)

Set up SSO profiles for each role you want to assume locally. The `infra-admin` profile (InfraAdmin permission set) is used here as it's the only role with broad enough permissions to run Terraform locally.

1. Configure your SSO profiles first time:

```zsh
aws configure sso
# SSO start URL: find in terraform output OR Identity Center → Settings → AWS access portal URL
# Region: ap-southeast-2
# Profile name: infra-admin
```

2. Later, you can login to sso roles by using the profile you configured:

```zsh
aws sso login --profile infra-admin
export AWS_PROFILE=infra-admin
```

Verify:

```zsh
aws sts get-caller-identity
# it should say something like:
# arn:aws:sts::123456789101:assumed-role/AWSReservedSSO_InfraAdmin_xxxx/your_email@example.com
```

Once confirmed working:

- Go to **IAM → Users → terraform → Delete**
- You no longer need static credentials (e.g. delete from your machine `~/.aws/credentials`)

## Day to day after bootstrap

When you need to make IAM changes or any foundation changes, log back in and then run terraform commands.

```zsh
aws sso login --profile infra-admin
export AWS_PROFILE=infra-admin
cd terraform
terraform plan
terraform apply
```

Your `infra-admin` session lasts 1 hour, other roles last 8 hours.

## Granting a new repo GitHub Actions CI access

CI access is controlled by the `github_repos` map in [terraform/github_repos.tf](terraform/github_repos.tf). Adding an entry there automatically creates a plan role and an apply role for that repo, each scoped to the correct S3 state bucket.

### 1. Add the repo

```hcl
locals {
  github_repos = {
    "aws-foundations" = { state_bucket = var.tf_state_bucket }
    "your-new-repo"   = { state_bucket = "tfstate-<account-id>-your-new-repo" }  # add it here
  }
}
```

Each value must include `state_bucket` - the S3 bucket used as that repo's Terraform backend. The plan and apply roles are each granted read/write access to that bucket.

### 2. Apply changes

Assumes you've setup SSO access with infra admin properly

```zsh
cd terraform
terraform plan   # confirm two new roles appear: github-actions-tf-plan-<repo> and github-actions-tf-apply-<repo>
terraform apply
```

### 3. Configure the workflow in the new repo

In the repo's GitHub Actions workflow, request the OIDC token and assume the appropriate role:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::<account-id>:role/github-actions-tf-plan-your-new-repo # or tf-apply-your-new-repo
      aws-region: ap-southeast-2
```

> Get your account ID: `aws sts get-caller-identity --query Account --output text`

The plan role trusts pushes to `main` and pull requests; the apply role trusts pushes to `main` only.

## Troubleshooting

**`terraform apply` fails with "Identity Center not found" or similar**
Identity Center must be enabled manually in the console before running Terraform (see step 2). Terraform cannot enable it.

**`terraform init` fails immediately**
The S3 state bucket must exist before `terraform init`. Complete step 6 first.

**SNS / budget alerts never arrive**
AWS sends a subscription confirmation email after the first `terraform apply`. You must click the link in that email before alerts will deliver.

**S3 bucket name already exists**
Bucket names are globally unique. If the generated name `tfstate-<account-id>-aws-foundations` is taken, choose a different suffix and update `backend.hcl` to match.

**`aws sso login` prompt appears mid-Terraform run**
The InfraAdmin session lasts 1 hour. Re-run `aws sso login --profile infra-admin` and retry.
