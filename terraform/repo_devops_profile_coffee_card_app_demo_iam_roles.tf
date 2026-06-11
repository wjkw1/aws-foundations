# ---------------------------------------------------------------------------
# devops-profile-coffee-card-app-demo: repo-specific IAM roles and permissions
#
# tf-apply role permissions — manages Lambda, API Gateway, CloudFront,
# S3, and ECR for the coffee card app infrastructure.
#
# github-ci role — used by CI workflows to push Docker images to ECR
# and deploy to Lambda by updating the function's container image.
# ---------------------------------------------------------------------------
resource "aws_iam_role_policy" "coffee_app_tf_apply" {
  name = "app-permissions"
  role = aws_iam_role.github_actions_tf_apply["devops-profile-coffee-card-app-demo"].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Lambda"
        Effect   = "Allow"
        Action   = ["lambda:*"]
        Resource = "*"
      },
      {
        Sid      = "APIGateway"
        Effect   = "Allow"
        Action   = ["apigateway:*"]
        Resource = "*"
      },
      {
        Sid      = "CloudFront"
        Effect   = "Allow"
        Action   = ["cloudfront:*"]
        Resource = "*"
      },
      {
        Sid    = "S3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::terraform-state-${data.aws_caller_identity.current.account_id}-coffee-card-app-demo",
          "arn:aws:s3:::terraform-state-${data.aws_caller_identity.current.account_id}-coffee-card-app-demo/*"
        ]
      },
      {
        Sid    = "S3AppBuckets"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:Get*",
          "s3:List*",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketAcl",
          "s3:PutBucketOwnershipControls",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketLogging",
          "s3:PutBucketTagging",
          "s3:PutBucketWebsite",
          "s3:PutBucketCORS",
          "s3:PutBucketLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetAccelerateConfiguration",
        ]
        Resource = [
          "arn:aws:s3:::coffee-card-*",
          "arn:aws:s3:::coffee-card-*/*"
        ]
      },
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid      = "ECR"
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/coffee-card-*"
      },
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole", "iam:GetRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/coffee-card-*"
      },
      {
        Sid    = "IAMAppRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/coffee-card-*"
      },
      {
        Sid    = "SSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DeleteParameter",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource",
          "ssm:ListTagsForResource",
        ]
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/coffee-card/*"
      },
      {
        # DescribeParameters doesn't support resource-level restriction.
        Sid      = "SSMDescribe"
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      },
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = ["dynamodb:*"]
        Resource = [
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/coffee-card-*",
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/coffee-card-*/index/*"
        ]
      },
      {
        # List/discovery actions don't support resource-level restriction.
        Sid    = "WAFList"
        Effect = "Allow"
        Action = [
          "wafv2:ListWebACLs",
          "wafv2:ListRuleGroups",
          "wafv2:ListAvailableManagedRuleGroups",
          "wafv2:ListAvailableManagedRuleGroupVersions"
        ]
        Resource = "*"
      },
      {
        Sid    = "WAF"
        Effect = "Allow"
        Action = ["wafv2:*"]
        Resource = [
          "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:*/webacl/coffee-card-*/*",
          "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:*/rulegroup/coffee-card-*/*",
          "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:*/ipset/coffee-card-*/*",
          "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:*/regexpatternset/coffee-card-*/*"
        ]
      },
      {
        Sid      = "WAFManagedRuleSets"
        Effect   = "Allow"
        Action   = ["wafv2:UpdateWebACL"]
        Resource = "arn:aws:wafv2:*:${data.aws_caller_identity.current.account_id}:*/managedruleset/*/*"
      },
      {
        Sid      = "CloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData", "cloudwatch:GetMetricData", "cloudwatch:GetMetricStatistics", "cloudwatch:ListMetrics", "cloudwatch:DescribeAlarms"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchAlarms"
        Effect = "Allow"
        Action = ["cloudwatch:*"]
        Resource = [
          "arn:aws:cloudwatch:*:${data.aws_caller_identity.current.account_id}:alarm:coffee-card-*",
          "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/coffee-card-*"
        ]
      },
      {
        # DescribeLogGroups doesn't support resource-level restriction.
        Sid      = "LogsDescribe"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        # API Gateway access logging is set up via the CreateLogDelivery
        # service-linked APIs, which don't support resource-level restriction.
        Sid    = "LogsDelivery"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
        ]
        Resource = "*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = [
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/coffee-card-*",
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/coffee-card-*:*",
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/apigateway/coffee-card-*",
          "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/apigateway/coffee-card-*:*"
        ]
      },
    ]
  })
}

resource "aws_iam_role" "github_ci_coffee_app" {
  name        = "github-actions-deploy-devops-profile-coffee-card-app-demo"
  description = "GitHub Actions - CI deploy for coffee-card-app-demo (ECR push + Lambda update)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/devops-profile-coffee-card-app-demo:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_ci_coffee_app" {
  name = "ecr-lambda-deploy"
  role = aws_iam_role.github_ci_coffee_app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
        ]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/coffee-card-api*"
      },
      {
        Sid    = "LambdaDeploy"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
        ]
        Resource = "arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:coffee-card-api*"
      },
    ]
  })
}
