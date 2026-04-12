# AWS Foundations

This repository set up the foundations for my aws account.

It uses terraform to manage the security, billing, identity, and access setup. Giving me repeatability when I need to securely setup an AWS account in future.

## Contents

- [What Terraform configures](#what-terraform-configures)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Day to day after bootstrap](#day-to-day-after-bootstrap)

## What Terraform configures

### Identity & access (`identity_center.tf`)

- **Identity Center user** — your SSO login
- **Permission sets** — IamAdmin, Developer, DeveloperReadOnly, Billing (all scoped with deny policies)
- **Account assignments** — all four sets bound to your account

### Security baseline (`security.tf`)

- **S3 account public access block** — prevents any bucket in the account from being made public by default
- **CloudTrail** — multi-region audit trail of every API call; logs stored in a dedicated S3 bucket with 90-day retention and file integrity validation enabled
- **CloudWatch Logs + root account alarm** — CloudTrail streams to a log group; a metric filter fires an SNS alert the moment the root user is used
- **SNS security-alerts topic** — email subscription to `user_email`; delivers root alarm notifications
- **AWS Budget** — monthly spend budget with alerts at 80% actual and 100% forecasted, sent to `user_email`

> **After first `terraform apply`:** AWS will send a subscription confirmation email to your `user_email`. You must click the confirmation link before the root account alarm and budget alerts will actually deliver.

## Prerequisites

I used Homebrew to install these:

- [Install Terraform CLI](https://developer.hashicorp.com/terraform/install)
- [Install AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Getting started

We will secure root, use aws cli to create the s3 backend, then use terraform to provision our IAM permission sets.

> Note: The Amazon S3 backend gives us encryption at rest and easy lockfile config. Lock files are innate now and no longer require dynamoDB.

### 1. Securing the `root` account

Do this before touching Terraform. The root account is the one thing you can never recover via code.

- Log in at aws.amazon.com with your root email
- Go to **IAM → Security credentials**
- Enable **MFA** (use an authenticator app)
- Do not create root access keys — ever

### 2. Enable identity center (manual — console only)

Terraform cannot enable this for you. This lets us use AWS SSO logins once the terraform applies the infrastructure.

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
  - Save the Key ID and Secret — you only see the secret once, so make sure to copy it

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

**backend.hcl** — your S3 state bucket name:

```hcl
bucket = "tfstate-<account-id>-aws-foundations"
```

**terraform.tfvars** — your Identity Center user details:

```hcl
user_email      = "you@example.com"
user_first_name = "First"
user_last_name  = "Last"
```

### 6. Create the s3 backend

Terraform needs this bucket to exist before `terraform init`.

You have two options, create it manually from the console or programatically like below.
Ensure that you:

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

Configure your SSO profile:

```
aws configure sso
# SSO start URL: find in Identity Center → Settings → AWS access portal URL
# Region: ap-southeast-2
# Profile name: admin
```

Log in:

```zsh
aws sso login --profile admin
export AWS_PROFILE=admin
```

Verify:

```zsh
aws sts get-caller-identity
# it should say something like:
# arn:aws:sts::123456789:assumed-role/AWSReservedSSO_IamAdmin_xxxx/your@email.com
```

Once confirmed working:

- Go to **IAM → Users → terraform → Delete**
- You no longer need static credentials (e.g. delete from your machine `~/.aws/credentials`)

## Day to day after bootstrap

When you need to make IAM changes or any foundation changes, log back in and then run terraform commands.

```zsh
aws sso login --profile admin
export AWS_PROFILE=admin
cd terraform
terraform plan
terraform apply
```

Your session lasts 8 hours, then re-run `aws sso login`.
