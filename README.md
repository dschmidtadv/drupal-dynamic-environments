# Drupal Dynamic Branch Environments on AWS

Terraform infrastructure for managing ephemeral and long-lasting Drupal environments tied to Git branches. This platform replaces legacy integration servers with a modern, containerized, cost-optimized solution.

## Architecture Overview

This infrastructure creates:

- **ECS Cluster**: EC2-based cluster with mixed On-Demand and Spot capacity
- **Aurora Serverless v2**: MySQL-compatible database with auto-scaling (0.5-2 ACU)
- **Application Load Balancer**: Wildcard routing to branch-specific environments
- **S3 Storage**: Persistent storage for Drupal public/private files
- **Auto Scaling**: Scheduled scale-to-zero during non-business hours
- **Dynamic Environments**: Modular design for branch-based deployments

## Features

### Cost Optimization

- **Spot Instances**: 50% of capacity uses Spot instances (configurable)
- **Aurora Serverless**: Scales down to 0.5 ACU during inactivity
- **Scale-to-Zero**: Automatically terminates instances outside business hours (8 PM - 7 AM ET)
- **Auto Scaling**: Task-level scaling based on CPU and memory utilization

### Dynamic Routing

- **Wildcard Domain**: `*.review.example.gov` routes to branch-specific services
- **Priority-Based**: Each branch gets a unique ALB listener rule
- **Automatic DNS**: Branch names are sanitized for DNS compatibility

### Security

- **Private Subnets**: All compute resources in private subnets
- **Security Groups**: Least-privilege access between components
- **Secrets Manager**: Database credentials stored securely
- **IAM Roles**: Separate execution and task roles with minimal permissions
- **Encryption**: S3 server-side encryption, Aurora encryption at rest

## Prerequisites

1. **Existing VPC**: You must have a VPC with private subnets
2. **IAM Instance Profile**: Cloud team must provide an ECS host instance profile
3. **ACM Certificate** (optional): For HTTPS support on `*.review.example.gov`
4. **Terraform**: >= 1.5.0
5. **AWS CLI**: Configured with appropriate credentials

## Quick Start

### 1. Configure Variables

Copy the example tfvars file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:

- `vpc_id` or `vpc_tag_name`: Your existing VPC
- `private_subnet_ids`: List of private subnet IDs
- `ecs_instance_profile_name`: IAM instance profile from Cloud Team
- `wildcard_domain`: Your domain (e.g., `*.review.example.gov`)
- `certificate_arn` (optional): ACM certificate for HTTPS

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Apply Infrastructure

```bash
terraform apply
```

### 5. Create Branch Environments

After the base infrastructure is deployed, you can create branch environments using the module:

```hcl
module "branch_feature_xyz" {
  source = "./modules/branch-environment"

  branch_name                 = "feature-xyz"
  project_name                = var.project_name
  ecs_cluster_id              = aws_ecs_cluster.main.id
  ecs_cluster_name            = aws_ecs_cluster.main.name
  vpc_id                      = data.aws_vpc.existing.id
  private_subnet_ids          = local.subnet_ids
  ecs_hosts_security_group_id = aws_security_group.ecs_hosts.id
  alb_arn                     = aws_lb.main.arn
  alb_listener_arn            = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  alb_security_group_id       = aws_security_group.alb.id
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
  ecs_task_role_arn           = aws_iam_role.ecs_task.arn
  aurora_endpoint             = aws_rds_cluster.aurora.endpoint
  aurora_database_name        = aws_rds_cluster.aurora.database_name
  aurora_secret_arn           = aws_secretsmanager_secret.aurora_master_password.arn
  s3_bucket_name              = aws_s3_bucket.drupal_files.id
  domain_suffix               = "review.example.gov"
  listener_rule_priority      = 100  # Must be unique per branch

  tags = var.tags
}
```

## CI/CD Integration

### AWS CodeBuild Integration

The module is designed to be called from AWS CodeBuild. Here's how to integrate:

#### 1. CodeBuild Environment Variables

Set these in your CodeBuild project:

- `BRANCH_NAME`: Git branch name (from `$CODEBUILD_WEBHOOK_HEAD_REF`)
- `TF_VAR_branch_name`: Pass to Terraform

#### 2. buildspec.yml Example

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Branch Name: $BRANCH_NAME"
      - export TF_VAR_branch_name=$BRANCH_NAME
      - terraform init

  build:
    commands:
      # Generate unique priority based on branch name
      - PRIORITY=$(echo $BRANCH_NAME | md5sum | tr -d 'a-z ' | cut -c 1-3)
      - echo "Listener priority: $PRIORITY"

      # Create/update branch environment
      - |
        terraform apply -auto-approve \
          -target=module.branch_${BRANCH_NAME} \
          -var="branch_name=${BRANCH_NAME}" \
          -var="listener_rule_priority=${PRIORITY}"

  post_build:
    commands:
      - terraform output -json > outputs.json
      - URL=$(jq -r '.branch_url.value' outputs.json)
      - echo "Environment URL: $URL"
```

#### 3. Dynamic Module Generation

For fully dynamic branch creation, use Terraform's `-target` flag or generate module blocks programmatically:

```bash
# Create a new branch environment
terraform apply -target=module.branch_${BRANCH_NAME} \
  -var="branch_name=${BRANCH_NAME}" \
  -var="listener_rule_priority=${PRIORITY}"

# Destroy a branch environment
terraform destroy -target=module.branch_${BRANCH_NAME}
```

## Configuration

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_id` | Existing VPC ID | - |
| `private_subnet_ids` | List of private subnet IDs | - |
| `ecs_instance_profile_name` | IAM instance profile from Cloud Team | `ecs-host-instance-profile` |
| `ecs_instance_type` | EC2 instance type | `t3.medium` |
| `spot_instance_percentage` | Percentage of Spot instances | `50` |
| `aurora_min_capacity` | Min Aurora ACUs | `0.5` |
| `aurora_max_capacity` | Max Aurora ACUs | `2` |
| `wildcard_domain` | Wildcard domain for branches | `*.review.example.gov` |
| `scale_to_zero_schedule` | Cron for scale-down (UTC) | `0 0 * * *` (midnight) |
| `scale_up_schedule` | Cron for scale-up (UTC) | `0 11 * * *` (11 AM) |

### Scheduled Scaling

By default, instances scale to zero at **8 PM ET** (midnight UTC) and scale up at **7 AM ET** (11 AM UTC).

To adjust:

```hcl
scale_to_zero_schedule = "0 0 * * *"  # Midnight UTC (8 PM ET)
scale_up_schedule      = "0 11 * * *" # 11 AM UTC (7 AM ET)
```

### Capacity Mix

Control the On-Demand vs. Spot ratio:

```hcl
spot_instance_percentage = 50  # 50% Spot, 50% On-Demand
```

Base UAT always gets at least 1 On-Demand instance.

## Module: branch-environment

The `branch-environment` module creates a complete Drupal environment for a specific Git branch.

### Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `branch_name` | Git branch name | `string` | Yes |
| `listener_rule_priority` | ALB listener rule priority | `number` | Yes |
| `project_name` | Project name | `string` | Yes |
| `ecs_cluster_id` | ECS cluster ID | `string` | Yes |
| `drupal_image` | Docker image | `string` | No (default: `drupal:10-apache`) |
| `drupal_cpu` | CPU units | `number` | No (default: `512`) |
| `drupal_memory` | Memory in MB | `number` | No (default: `1024`) |
| `desired_count` | Desired task count | `number` | No (default: `1`) |

### Outputs

| Name | Description |
|------|-------------|
| `service_name` | ECS service name |
| `hostname` | Full hostname (e.g., `feature-xyz.review.example.gov`) |
| `url` | Full URL (e.g., `https://feature-xyz.review.example.gov`) |
| `log_group_name` | CloudWatch log group name |

### Branch Naming

Branch names are automatically sanitized for DNS:

- Underscores replaced with hyphens
- Converted to lowercase
- Example: `feature_New_Feature` → `feature-new-feature.review.example.gov`

## Outputs

After applying, Terraform outputs key values:

```bash
terraform output
```

Key outputs:

- `alb_dns_name`: ALB DNS name for CNAME records
- `ecs_cluster_name`: Cluster name for service deployments
- `aurora_cluster_endpoint`: Database endpoint
- `s3_bucket_name`: Drupal files bucket
- `branch_environment_module_usage`: Instructions for creating branches

## DNS Configuration

Point your wildcard domain to the ALB:

```
*.review.example.gov.  CNAME  drupal-dynamic-alb-1234567890.us-east-1.elb.amazonaws.com
```

Get the ALB DNS name:

```bash
terraform output alb_dns_name
```

## Security Considerations

1. **IAM Instance Profile**: Ensure the Cloud Team's instance profile has:
   - `AmazonEC2ContainerServiceforEC2Role`
   - CloudWatch Logs write permissions
   - ECR pull permissions

2. **Database Credentials**: Stored in AWS Secrets Manager
   - Retrieve via: `aws secretsmanager get-secret-value --secret-id <arn>`
   - **Never commit credentials to Git**

3. **S3 Bucket**: Public access is blocked by default
   - Access via IAM task role only

4. **Security Groups**: Follow least-privilege principle
   - ALB: Allows 80/443 from internet
   - ECS Hosts: Allow traffic from ALB only
   - Aurora: Allow 3306 from ECS hosts only

## Cost Estimates

Approximate monthly costs (us-east-1, 8 hours/day usage):

| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| ECS EC2 (2x t3.medium, 8hr/day) | On-Demand + Spot | ~$25 |
| Aurora Serverless v2 | 0.5-2 ACU, 8hr/day | ~$15 |
| ALB | Standard | ~$16 |
| S3 | 10 GB storage + requests | ~$1 |
| **Total** | | **~$57/month** |

Actual costs vary based on:
- Number of active branches
- Data transfer
- Task scaling

## Maintenance

### Updating ECS AMI

The latest ECS-optimized AMI is automatically fetched via SSM parameter. To update:

```bash
terraform apply -refresh=true
```

### Rotating Database Credentials

1. Generate new password in Secrets Manager
2. Update Aurora master password
3. Update secret version
4. Restart ECS tasks

### Cleanup Old Branches

Remove branch environments when branches are merged/deleted:

```bash
terraform destroy -target=module.branch_feature_xyz
```

## Troubleshooting

### ECS Tasks Not Starting

Check:
1. Instance capacity: `aws ecs describe-clusters --clusters <cluster-name>`
2. Task logs: CloudWatch Logs `/ecs/<project>-<branch>`
3. Task role permissions

### Database Connection Issues

Check:
1. Security group rules: Aurora SG allows ECS hosts
2. Secrets Manager: Credentials are correct
3. Aurora status: `aws rds describe-db-clusters`

### ALB Not Routing

Check:
1. Listener rules: `aws elbv2 describe-rules --listener-arn <arn>`
2. Target health: `aws elbv2 describe-target-health --target-group-arn <arn>`
3. DNS resolution: `dig <branch>.review.example.gov`

## License

This project is provided as-is for infrastructure management.

## Support

For issues or questions:
1. Check CloudWatch Logs
2. Review AWS Console for resource status
3. Contact your Cloud Team for IAM/networking issues
