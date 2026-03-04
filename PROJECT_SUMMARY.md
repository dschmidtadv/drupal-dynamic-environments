# Project Summary: Drupal Dynamic Branch Environments

## Overview

This Terraform infrastructure creates a containerized platform for running ephemeral and long-lasting Drupal environments tied to Git branches, replacing a legacy integration server with a modern, cost-optimized AWS solution.

## Architecture Components

### Compute Layer
- **ECS Cluster**: EC2-based cluster for running Drupal containers
- **Mixed Capacity**: 50/50 split between On-Demand (base UAT) and Spot instances (ephemeral branches)
- **Auto Scaling**: Dynamic scaling based on CPU/memory utilization
- **Scheduled Scaling**: Scale-to-zero outside business hours (8 PM - 7 AM ET)

### Data Layer
- **Aurora Serverless v2**: MySQL 8.0 compatible database
- **Capacity**: 0.5 - 2 ACUs with auto-pause
- **Cost Optimization**: Scales down during inactivity

### Application Layer
- **Application Load Balancer**: Wildcard routing (`*.review.example.gov`)
- **Dynamic Routing**: Host-based routing to branch-specific services
- **Priority Rules**: Each branch gets unique listener priority

### Storage
- **S3 Bucket**: Persistent storage for Drupal public/private files
- **Versioning**: Enabled for data protection
- **Lifecycle**: Automatic transition to IA/Glacier

### Security
- **IAM Roles**: Separate execution and task roles
- **Secrets Manager**: Secure database credential storage
- **Security Groups**: Least-privilege network access
- **Encryption**: S3 and Aurora encryption at rest

## Key Features

### 1. Dynamic Branch Environments
Each Git branch can have its own isolated Drupal environment:
- Unique URL: `{branch-name}.review.example.gov`
- Isolated ECS service
- Shared database (separate schemas)
- Shared S3 bucket (namespaced by branch)

### 2. Cost Optimization
- **Spot Instances**: Up to 50% savings on compute
- **Aurora Serverless**: Pay only for capacity used
- **Scale-to-Zero**: Automatic shutdown overnight
- **Lifecycle Policies**: Automatic data archival

Estimated monthly cost: **~$57/month** (8 hours/day usage)

### 3. CI/CD Integration
- **AWS CodeBuild**: Automated deployments
- **Git Webhooks**: Trigger on branch creation/updates
- **Dynamic Priority**: Hash-based listener rule priority
- **Automated Cleanup**: Remove environments when branches deleted

### 4. High Availability
- **Multi-AZ**: Resources span multiple availability zones
- **Auto Scaling**: Automatic capacity adjustment
- **Health Checks**: ALB and ECS health monitoring
- **Circuit Breaker**: Automatic rollback on failed deployments

## File Structure

```
.
├── main.tf                      # Provider and data sources
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── terraform.tfvars.example     # Example configuration
├── ecs.tf                       # ECS cluster and capacity providers
├── iam.tf                       # IAM roles and policies
├── aurora.tf                    # Aurora Serverless cluster
├── s3.tf                        # S3 bucket configuration
├── alb.tf                       # Application Load Balancer
├── example-branch-usage.tf      # Example branch deployments
├── buildspec.yml                # AWS CodeBuild configuration
├── modules/
│   └── branch-environment/      # Reusable module for branches
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── scripts/
│   └── manage-branch.sh         # Branch management utility
├── README.md                    # Full documentation
├── QUICKSTART.md                # Quick start guide
└── .gitignore                   # Git ignore patterns
```

## Module: branch-environment

Reusable module that creates a complete Drupal environment for a Git branch.

### Creates:
- ECS Task Definition (Drupal container)
- ECS Service (with auto-scaling)
- ALB Target Group
- ALB Listener Rule (host-based routing)
- CloudWatch Log Group

### Inputs:
- `branch_name`: Git branch name
- `listener_rule_priority`: Unique priority (100-999)
- `drupal_image`: Docker image
- `drupal_cpu`: CPU units
- `drupal_memory`: Memory in MB
- `desired_count`: Initial task count

### Outputs:
- `service_name`: ECS service name
- `hostname`: Full hostname
- `url`: Full URL
- `log_group_name`: CloudWatch log group

## Deployment Workflow

### Base Infrastructure
1. Configure `terraform.tfvars`
2. `terraform init`
3. `terraform plan`
4. `terraform apply`
5. Configure DNS (CNAME to ALB)

### Branch Environments

#### Manual:
```bash
./scripts/manage-branch.sh create feature-xyz
```

#### CI/CD:
- Push to Git branch
- CodeBuild webhook triggered
- Buildspec generates module configuration
- Terraform applies changes
- URL saved to SSM Parameter Store

## Scheduled Scaling

### Default Schedule (Eastern Time):
- **Scale Down**: 8:00 PM ET (00:00 UTC)
  - On-Demand ASG: min=0, desired=0
  - Spot ASG: min=0, desired=0
- **Scale Up**: 7:00 AM ET (11:00 UTC)
  - On-Demand ASG: min=1, desired=1
  - Spot ASG: min=0, desired=1

### Customization:
Edit `terraform.tfvars`:
```hcl
scale_to_zero_schedule = "0 0 * * *"  # Midnight UTC
scale_up_schedule      = "0 11 * * *" # 11 AM UTC
```

## Security Considerations

### IAM
- **Host Profile**: Provided by Cloud Team (EC2 container service access)
- **Task Execution Role**: ECS agent permissions (ECR, Logs, Secrets)
- **Task Role**: Application permissions (S3, Secrets Manager)

### Network
- **VPC**: Existing VPC (not created by this code)
- **Private Subnets**: All compute resources
- **Public Subnets**: ALB only
- **Security Groups**:
  - ALB: 80/443 from internet
  - ECS Hosts: Dynamic ports from ALB
  - Aurora: 3306 from ECS hosts

### Secrets
- **Secrets Manager**: Database credentials
- **Environment Variables**: Non-sensitive configuration
- **IAM Policies**: Least-privilege access

## Capacity Planning

### ECS Instances
- **Type**: t3.medium (2 vCPU, 4 GB RAM)
- **Base**: 1 On-Demand (UAT)
- **Spot**: 0-10 instances (ephemeral branches)
- **Scaling**: Managed by ECS capacity providers

### Aurora
- **Min**: 0.5 ACU (1 GB RAM, ~0.5 CPU)
- **Max**: 2 ACU (4 GB RAM, ~2 CPU)
- **Auto-Pause**: 5 minutes of inactivity

### Task Resources
- **CPU**: 512 units (0.5 vCPU)
- **Memory**: 1024 MB (1 GB)
- **Scaling**: 1-5 tasks per service

## Monitoring and Logging

### CloudWatch Logs
- **ALB**: `/aws/alb/drupal-dynamic`
- **ECS Tasks**: `/ecs/{project}-{branch}`
- **Retention**: 7 days

### Metrics
- **ECS**: CPU/Memory utilization, running tasks
- **Aurora**: Connections, CPU, serverless capacity
- **ALB**: Request count, target health, response time

### Alarms (Recommended)
- ECS task failures
- Aurora connection errors
- ALB unhealthy targets
- High CPU/memory usage

## Best Practices

### Branch Naming
- Use alphanumeric and hyphens only
- Examples: `uat`, `feature-auth`, `bugfix-123`
- Avoid: underscores, special characters

### Listener Priorities
- UAT: 10 (highest priority)
- Staging: 20
- Features: 100-999 (auto-generated)
- Default: Catch-all

### Resource Tagging
```hcl
tags = {
  Project     = "DrupalDynamicEnvironments"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Branch      = "feature-xyz"
}
```

### Database Management
- Use separate schemas per branch
- Implement backup strategy
- Monitor connection pooling
- Clean up old schemas

## Maintenance

### Regular Tasks
- **Weekly**: Review running branches, clean up merged branches
- **Monthly**: Review Aurora performance, optimize queries
- **Quarterly**: Update ECS-optimized AMI, review costs

### Updates
- **Terraform**: `terraform init -upgrade`
- **Providers**: Update version constraints in `main.tf`
- **AMI**: Auto-fetched from AWS SSM parameter

### Backup Strategy
- **Aurora**: Automated daily snapshots (7-day retention)
- **S3**: Versioning enabled
- **Terraform State**: Store in S3 with versioning (not implemented)

## Troubleshooting Guide

### Common Issues

1. **Tasks Not Starting**
   - Check EC2 instance capacity
   - Verify IAM permissions
   - Review CloudWatch Logs

2. **Database Connection Failed**
   - Verify security group rules
   - Check Aurora is running (not paused)
   - Validate Secrets Manager credentials

3. **ALB Health Checks Failing**
   - Verify Drupal is responding on port 80
   - Check security group allows ALB → ECS
   - Review task logs for errors

4. **High Costs**
   - Check for orphaned resources
   - Verify scale-to-zero is working
   - Review Aurora capacity settings

## Future Enhancements

### Potential Improvements
1. **RDS Proxy**: Connection pooling for database
2. **CloudFront**: CDN for static assets
3. **ElastiCache**: Redis for Drupal caching
4. **EFS**: Shared file system for modules
5. **WAF**: Web Application Firewall
6. **Route 53**: Automated DNS management
7. **Lambda**: Automated branch cleanup
8. **Terraform State**: Remote state in S3

### Scaling Options
- **Fargate**: Migrate from EC2 to Fargate for easier management
- **Multi-Region**: Deploy to multiple regions
- **Blue/Green**: Implement deployment strategies
- **Canary**: Gradual traffic shifting

## Related Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Drupal Docker Images](https://hub.docker.com/_/drupal)

## License

This infrastructure code is provided as-is for internal use.

## Contributors

Generated by AI assistant for AWS Cloud Infrastructure Engineering.
