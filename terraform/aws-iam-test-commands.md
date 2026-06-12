# AWS Test IAM Policy commands

1. Get the account id and cloudfront variables

   ```zsh
   read -r CF_DIST_ID CF_DOMAIN <<< "$(aws cloudfront list-distributions \
   --query "DistributionList.Items[?Origins.Items[?contains(DomainName, 'coffee-card-frontend-prod')]].[Id, DomainName]" --output text)"
   export CF_DIST_ID CF_DOMAIN
   export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
   ```

2. aws cloudfront list-distributions — action only supports \* resource:

   ```zsh
   aws iam simulate-principal-policy \
   --policy-source-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-deploy-devops-profile-coffee-card-app-demo \
   --action-names cloudfront:ListDistributions \
   --resource-arns "\*"
   ```

3. aws s3 sync dist/ s3://coffee-card-frontend-prod --delete — needs ListBucket on the bucket ARN, plus PutObject/DeleteObject on object ARNs:

   ```zsh
   aws iam simulate-principal-policy \
   --policy-source-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-deploy-devops-profile-coffee-card-app-demo \
     --action-names s3:ListBucket \
     --resource-arns "arn:aws:s3:::coffee-card-frontend-prod" \
     --context-entries ContextKeyName=aws:ResourceAccount,ContextKeyValues=${AWS_ACCOUNT_ID},ContextKeyType=string
   ```

   ```zsh
   aws iam simulate-principal-policy \
   --policy-source-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-deploy-devops-profile-coffee-card-app-demo \
     --action-names s3:PutObject s3:DeleteObject \
     --resource-arns "arn:aws:s3:::coffee-card-frontend-prod/index.html" \
     --context-entries ContextKeyName=aws:ResourceAccount,ContextKeyValues=${AWS_ACCOUNT_ID},ContextKeyType=string
   ```

4. aws cloudfront create-invalidation — this action does support resource-level permissions on the distribution ARN. You'll need the distribution ID for the prod frontend (check Terraform/console):

   ```zsh
   aws iam simulate-principal-policy \
   --policy-source-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-deploy-devops-profile-coffee-card-app-demo \
     --action-names cloudfront:CreateInvalidation \
     --resource-arns "arn:aws:cloudfront::${AWS_ACCOUNT_ID}:distribution/${CF_DIST_ID}"
   ```
