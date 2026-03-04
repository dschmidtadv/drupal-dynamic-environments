# Quick Start Guide

Get your Drupal Dynamic Branch Environments up and running in minutes.

## Prerequisites

- AWS Account with appropriate permissions
- Existing VPC with private and public subnets
- IAM instance profile for ECS hosts (provided by Cloud Team)
- Terraform >= 1.5.0 installed
- AWS CLI configured

## Step 1: Clone and Configure

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

### Required Configuration

Edit `terraform.tfvars` and set:

```hcl
# VPC - Option 1: Direct ID
vpc_id = "vpc-0123456789abcdef0"

# VPC - Option 2: Lookup by tag
# vpc_tag_name = "main-vpc"

# Subnets
private_subnet_ids = [
  "subnet-abc123",
  "subnet-def456",
  "subnet-ghi789"
]

# IAM (from Cloud Team)
ecs_instance_profile_name = "your-ecs-instance-profile"

# Domain
wildcard_domain = "*.review.example.gov"

# Optional: HTTPS Certificate
# certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
```

## Step 2: Initialize Terraform

```bash
terraform init
```

## Step 3: Review the Plan

```bash
terraform plan
```

Review what will be created:
- ECS Cluster with Auto Scaling Groups
- Aurora Serverless v2 MySQL database
- Application Load Balancer
- S3 bucket for Drupal files
- IAM roles and security groups

## Step 4: Deploy Base Infrastructure

```bash
terraform apply
```

Type `yes` to confirm.

This takes about 10-15 minutes to complete.

## Step 5: Configure DNS

After deployment, point your wildcard domain to the ALB:

```bash
# Get ALB DNS name
terraform output alb_dns_name
```

Create a CNAME record:

```
*.review.example.gov  CNAME  drupal-dynamic-alb-xxx.us-east-1.elb.amazonaws.com
```

## Step 6: Create Your First Branch Environment

### Option A: Using the Management Script

```bash
./scripts/manage-branch.sh create uat

# Check status
./scripts/manage-branch.sh status uat

# View URL
terraform output branch_uat_url
```

### Option B: Manually Edit Terraform

The example file `example-branch-usage.tf` already includes UAT and feature-auth branches.

```bash
terraform apply
```

## Step 7: Access Your Environment

Once deployed, access your Drupal site:

```
https://uat.review.example.gov
```

## Step 8: Set Up CI/CD (Optional)

### AWS CodeBuild Integration

1. Create a CodeBuild project
2. Use the provided `buildspec.yml`
3. Configure environment variables:
   - `BRANCH_NAME`: From Git webhook
4. Connect to your Git repository

The pipeline will automatically:
- Deploy new branch environments
- Update existing environments
- Clean up when branches are deleted

## Managing Branch Environments

### List All Branches

```bash
./scripts/manage-branch.sh list
```

### Check Branch Status

```bash
./scripts/manage-branch.sh status feature-auth
```

### Remove a Branch

```bash
./scripts/manage-branch.sh destroy feature-auth
```

## Common Tasks

### View Database Credentials

```bash
# Get secret ARN
terraform output aurora_secret_arn

# Retrieve credentials
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw aurora_secret_arn) \
  --query SecretString \
  --output text | jq .
```

### Check ECS Service Status

```bash
# List services
aws ecs list-services \
  --cluster $(terraform output -raw ecs_cluster_name)

# Describe a service
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services drupal-dynamic-uat
```

### View Logs

```bash
# Get log group
terraform output -json | jq -r '.branch_uat_log_group.value'

# Tail logs
aws logs tail /ecs/drupal-dynamic-uat --follow
```

### Update Drupal Image

Edit the module configuration and change `drupal_image`:

```hcl
module "branch_uat" {
  # ...
  drupal_image = "drupal:10.1-apache"
  # ...
}
```

Apply changes:

```bash
terraform apply
```

## Cost Optimization

### Schedule Scale-Down

Already configured! Instances scale to zero:
- **Down**: 8 PM ET (midnight UTC)
- **Up**: 7 AM ET (11 AM UTC)

To adjust, edit `terraform.tfvars`:

```hcl
scale_to_zero_schedule = "0 0 * * *"  # Midnight UTC
scale_up_schedule      = "0 11 * * *" # 11 AM UTC
```

### Monitor Costs

```bash
# Check running instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=drupal-dynamic-*" \
  --query "Reservations[].Instances[].[InstanceId,State.Name,InstanceType]" \
  --output table

# Check Aurora capacity
aws rds describe-db-clusters \
  --db-cluster-identifier $(terraform output -raw ecs_cluster_name | sed 's/drupal-dynamic-environments/drupal-dynamic-aurora/') \
  --query "DBClusters[0].ServerlessV2ScalingConfiguration"
```

## Troubleshooting

### ECS Tasks Not Starting

1. Check capacity:
   ```bash
   aws ecs describe-clusters \
     --clusters $(terraform output -raw ecs_cluster_name)
   ```

2. Check instance profile permissions
3. Review CloudWatch Logs

### Database Connection Failed

1. Verify security groups allow ECS → Aurora
2. Check Aurora is running (not paused)
3. Verify credentials in Secrets Manager

### ALB Returns 503

1. Check target health:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <from-terraform-output>
   ```

2. Verify ECS tasks are running
3. Check security group rules

### Domain Not Resolving

1. Verify DNS propagation:
   ```bash
   dig uat.review.example.gov
   ```

2. Check CNAME points to correct ALB DNS name
3. Wait for DNS propagation (up to 48 hours)

## Next Steps

- **Customize Drupal**: Update task definition with your Drupal configuration
- **Add Monitoring**: Set up CloudWatch dashboards and alarms
- **Enable Backups**: Configure automated Aurora backups
- **SSL Certificate**: Add ACM certificate for HTTPS
- **Scaling Policies**: Adjust auto-scaling thresholds

## Support

For issues:
1. Check [README.md](README.md) for detailed documentation
2. Review CloudWatch Logs: `/ecs/<project>-<branch>`
3. Verify AWS Console for resource status
4. Contact your Cloud Team for IAM/networking issues

## Clean Up

To destroy all resources:

```bash
# Remove all branch environments first
terraform destroy -target=module.branch_uat
terraform destroy -target=module.branch_feature_auth

# Then destroy base infrastructure
terraform destroy
```

**Warning**: This will delete the Aurora database. Ensure you have backups!
