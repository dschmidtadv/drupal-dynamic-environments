# GitHub Actions Setup Guide

Complete guide to set up automated infrastructure deployment using GitHub Actions.

## Overview

This repository includes 4 GitHub Actions workflows:

1. **Terraform Plan** - Validates and plans changes on PRs
2. **Terraform Apply** - Deploys infrastructure on merge to main
3. **Branch Environment** - Creates/destroys branch-specific environments
4. **Compliance Check** - Validates governance rules and security

## Prerequisites

Before setting up GitHub Actions, you need:

1. AWS Account with appropriate permissions
2. GitHub repository with this code
3. AWS IAM role for GitHub Actions OIDC

## Step 1: Configure AWS OIDC for GitHub Actions

GitHub Actions can authenticate to AWS using OpenID Connect (OIDC) without storing long-lived credentials.

### Create IAM OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Create IAM Policy for Terraform

Create a file `terraform-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "rds:*",
        "s3:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "cloudwatch:*",
        "logs:*",
        "iam:*",
        "secretsmanager:*",
        "ssm:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Create the policy:

```bash
aws iam create-policy \
  --policy-name GitHubActionsTerraformPolicy \
  --policy-document file://terraform-policy.json
```

### Create IAM Role for GitHub Actions

Create a file `trust-policy.json` (replace `YOUR_GITHUB_ORG` and `YOUR_REPO_NAME`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

Create the role:

```bash
# Replace ACCOUNT_ID in trust-policy.json first
aws iam create-role \
  --role-name GitHubActionsTerraformRole \
  --assume-role-policy-document file://trust-policy.json

# Attach the policy
aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/GitHubActionsTerraformPolicy
```

## Step 2: Configure GitHub Secrets and Variables

### GitHub Secrets

Navigate to your repository → Settings → Secrets and variables → Actions

**Required Secrets:**

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::ACCOUNT_ID:role/GitHubActionsTerraformRole` | IAM role for GitHub Actions |

### GitHub Variables

Navigate to your repository → Settings → Secrets and variables → Actions → Variables

**Optional Variables:**

| Variable Name | Value | Description |
|---------------|-------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for deployment |

## Step 3: Configure Terraform Backend for State

GitHub Actions requires a remote backend for Terraform state.

### Create S3 Bucket and DynamoDB Table

```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket your-terraform-state-bucket \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

### Update main.tf with Backend Configuration

Add to `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "drupal-dynamic/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }

  required_version = ">= 1.5.0"
  # ... rest of configuration
}
```

## Step 4: Create terraform.tfvars

Create a `terraform.tfvars` file (or use GitHub Actions to generate it):

```hcl
aws_region   = "us-east-1"
project_name = "drupal-dynamic"
environment  = "production"

vpc_cidr = "10.0.0.0/16"
az_count = 3

wildcard_domain = "*.review.example.gov"

# Optional: ACM certificate ARN
# certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."

tags = {
  Project     = "DrupalDynamicEnvironments"
  Environment = "production"
  ManagedBy   = "GitHubActions"
}
```

**Important**: Either commit `terraform.tfvars` or use GitHub secrets to generate it dynamically.

## Step 5: Set Up GitHub Environment

Navigate to Settings → Environments → New environment

**Create "production" environment:**

1. Name: `production`
2. Protection rules:
   - ✅ Required reviewers (add team members)
   - ✅ Wait timer: 0 minutes (or add delay if desired)
3. Environment secrets: (inherit from repository)

This ensures deployments require manual approval.

## Step 6: Test the Workflows

### Test 1: Terraform Plan (PR)

1. Create a new branch: `git checkout -b test/github-actions`
2. Make a small change to any `.tf` file
3. Commit and push: `git push origin test/github-actions`
4. Create a Pull Request
5. GitHub Actions will automatically:
   - Run `terraform fmt -check`
   - Run `terraform validate`
   - Run `terraform plan`
   - Comment the plan on your PR

### Test 2: Terraform Apply (Merge)

1. Merge the Pull Request
2. GitHub Actions will automatically:
   - Deploy infrastructure to AWS
   - Output deployment summary
   - Save outputs for reference

### Test 3: Branch Environment (Manual)

1. Go to Actions → Deploy Branch Environment
2. Click "Run workflow"
3. Enter:
   - Branch name: `uat`
   - Action: `deploy`
   - Listener priority: (leave as 0 for auto)
4. Click "Run workflow"
5. GitHub Actions will:
   - Create branch environment configuration
   - Deploy ECS service
   - Register with ALB
   - Output environment URL

### Test 4: Compliance Check

Runs automatically on:
- Every Pull Request
- Every push to main
- Weekly (Mondays)
- Manual trigger

## Workflow Details

### 1. Terraform Plan (`.github/workflows/terraform-plan.yml`)

**Triggers:**
- Pull requests to `main`
- Changes to `*.tf` or `*.tfvars` files

**Actions:**
- Format check
- Validation
- Plan generation
- PR comment with results

**Artifacts:**
- Terraform plan file (5-day retention)

---

### 2. Terraform Apply (`.github/workflows/terraform-apply.yml`)

**Triggers:**
- Push to `main` branch
- Manual workflow dispatch

**Actions:**
- Initialize Terraform
- Validate configuration
- Apply changes (with approval)
- Output infrastructure details

**Environment:**
- `production` (requires approval)

**Manual Options:**
- `apply` - Deploy infrastructure
- `destroy` - Destroy infrastructure

---

### 3. Branch Environment (`.github/workflows/branch-environment.yml`)

**Triggers:**
- Manual workflow dispatch only

**Inputs:**
- `branch_name` - Name of the branch environment
- `action` - `deploy` or `destroy`
- `listener_priority` - ALB rule priority (0 = auto)

**Actions:**
- Sanitize branch name
- Generate Terraform module configuration
- Deploy or destroy environment
- Store URL in SSM Parameter Store
- Commit configuration file

**Outputs:**
- Environment URL
- ECS service name
- Access instructions

---

### 4. Compliance Check (`.github/workflows/compliance-check.yml`)

**Triggers:**
- Pull requests
- Push to `main`
- Weekly schedule (Mondays)
- Manual trigger

**Checks:**
- COMPLIANCE.md exists and complete
- Private subnet enforcement
- IAM role separation
- Secrets Manager usage
- Circuit breakers enabled
- Traffic-based scaling configured

**Tools:**
- Custom validation scripts
- tfsec security scanner

---

## Usage Examples

### Deploy Base Infrastructure

```bash
# Merge PR to main branch
git checkout main
git pull
git merge feature-branch
git push

# GitHub Actions automatically deploys
```

### Create UAT Environment

1. Go to Actions → Deploy Branch Environment
2. Run workflow:
   - Branch name: `uat`
   - Action: `deploy`
3. Wait 2-3 minutes
4. Access: `https://uat.review.example.gov`

### Create Feature Environment

1. Go to Actions → Deploy Branch Environment
2. Run workflow:
   - Branch name: `feature-new-auth`
   - Action: `deploy`
   - Priority: `150` (or 0 for auto)
3. Access: `https://feature-new-auth.review.example.gov`

### Destroy Environment

1. Go to Actions → Deploy Branch Environment
2. Run workflow:
   - Branch name: `feature-new-auth`
   - Action: `destroy`

### Manual Infrastructure Destroy

1. Go to Actions → Terraform Apply
2. Run workflow:
   - Action: `destroy`
3. Requires production environment approval

## Monitoring Deployments

### View Workflow Runs

Navigate to Actions tab to see:
- Running workflows
- Completed workflows
- Workflow logs
- Deployment summaries

### View Terraform Outputs

After successful deployment, outputs are shown in workflow summary:
- ALB DNS name
- ECS cluster name
- VPC ID
- Environment URLs

### View Logs

```bash
# View ECS task logs
aws logs tail /ecs/drupal-dynamic-uat --follow

# View workflow logs
# Available in GitHub Actions UI
```

## Troubleshooting

### Issue: "Error assuming AWS role"

**Solution:**
- Verify `AWS_ROLE_ARN` secret is correct
- Check IAM trust policy includes your repository
- Ensure OIDC provider is configured

### Issue: "Backend initialization failed"

**Solution:**
- Verify S3 bucket exists and is accessible
- Check DynamoDB table exists
- Ensure IAM role has S3 and DynamoDB permissions

### Issue: "Terraform plan failed"

**Solution:**
- Check terraform.tfvars is present or generated
- Verify all required variables are set
- Review workflow logs for specific errors

### Issue: "Deployment requires approval"

**Solution:**
- Go to Actions → Running workflow
- Review deployment
- Click "Review deployments"
- Approve or reject

## Security Best Practices

1. **Use OIDC** - No long-lived credentials in GitHub
2. **Require PR reviews** - All changes reviewed before merge
3. **Environment protection** - Production requires approval
4. **State locking** - DynamoDB prevents concurrent modifications
5. **Encrypted state** - S3 bucket encryption enabled
6. **Audit trail** - All deployments logged in Actions
7. **Secret scanning** - Enable GitHub secret scanning
8. **Dependabot** - Enable for action version updates

## Cost Optimization

GitHub Actions minutes:
- Public repos: Free
- Private repos: 2,000 minutes/month free (Team plan)

Tips:
- Use caching for Terraform providers
- Only trigger on relevant file changes
- Use workflow artifacts instead of re-running

## Advanced Configuration

### Custom Terraform Variables via GitHub Secrets

```yaml
- name: Generate terraform.tfvars
  run: |
    cat > terraform.tfvars <<EOF
    aws_region   = "${{ vars.AWS_REGION }}"
    vpc_cidr     = "${{ secrets.VPC_CIDR }}"
    wildcard_domain = "${{ secrets.WILDCARD_DOMAIN }}"
    EOF
```

### Matrix Builds for Multiple Environments

```yaml
strategy:
  matrix:
    environment: [dev, staging, production]
```

### Slack Notifications

Add to workflow:

```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## Next Steps

1. ✅ Configure AWS OIDC and IAM role
2. ✅ Add GitHub secrets
3. ✅ Configure S3 backend
4. ✅ Create production environment
5. ✅ Test workflows with a PR
6. ✅ Deploy base infrastructure
7. ✅ Create branch environments
8. 📚 Train team on workflow usage

## Support

For issues with:
- **GitHub Actions**: Check workflow logs
- **Terraform**: Review Terraform output
- **AWS**: Check CloudWatch Logs and ECS console
- **Compliance**: Review COMPLIANCE.md

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS OIDC for GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform Backend Configuration](https://www.terraform.io/language/settings/backends/s3)
- [ECS Deployment with GitHub Actions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html)
