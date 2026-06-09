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
        Sid      = "ECR"
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "*"
      },
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole", "iam:GetRole"]
        Resource = "*"
      },
      {
        Sid      = "DynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = "*"
      },
      {
        Sid      = "WAF"
        Effect   = "Allow"
        Action   = ["wafv2:*", "waf-regional:*"]
        Resource = "*"
      },
      {
        Sid      = "Observability"
        Effect   = "Allow"
        Action   = ["cloudwatch:*", "logs:*"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "github_ci_coffee_app" {
  name        = "github-actions-ci-devops-profile-coffee-card-app-demo"
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
