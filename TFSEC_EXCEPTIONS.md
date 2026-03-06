# tfsec Security Exceptions

This document explains intentional exceptions to tfsec security rules for this infrastructure.

## Network Security

### Public ALB (aws-elb-alb-not-public)

**Rule**: Load balancer is exposed publicly
**Status**: ACCEPTED - By Design

**Justification**: The Application Load Balancer MUST be public-facing to receive traffic from the internet. This is the entry point for all Drupal branch environments.

**Mitigations**:
- ALB is the ONLY resource in public subnets
- All compute resources (ECS, Aurora) are in private subnets
- Security groups restrict ALB to ports 80/443 only
- WAF rules can be added for additional protection

### Security Group Egress Rules (aws-ec2-no-public-egress-sgr)

**Rule**: Security group rule allows egress to 0.0.0.0/0
**Status**: ACCEPTED - Required for Functionality

**Justification**: Egress to the internet is required for:
- **ECS Hosts**: Pull Docker images from ECR, download updates, send CloudWatch logs
- **Aurora**: Access AWS APIs for managed service operations
- **ALB**: Forward requests to backend targets

**Mitigations**:
- Egress is controlled through NAT Gateways (one per AZ)
- CloudWatch Logs track all network flows via VPC Flow Logs
- Private subnets prevent direct inbound access
- Security groups still enforce source/destination restrictions on ingress

### Public ALB Ingress (aws-ec2-no-public-ingress-sgr)

**Rule**: Security group allows ingress from 0.0.0.0/0
**Status**: ACCEPTED - By Design

**Justification**: The ALB security group allows HTTP (80) and HTTPS (443) from the internet, which is required for public web application access.

**Mitigations**:
- Only ports 80 and 443 are exposed
- HTTP redirects to HTTPS when certificate is configured
- ALB drops invalid headers (drop_invalid_header_fields = true)
- Backend resources are isolated in private subnets
- Consider adding AWS WAF for application-layer protection

### HTTP Listener (aws-elb-http-not-used)

**Rule**: ALB listener uses HTTP instead of HTTPS
**Status**: ACCEPTED - Conditional

**Justification**: HTTP listener is required for initial setup and health checks. When a certificate ARN is provided, the HTTP listener automatically redirects to HTTPS.

**Implementation**:
```hcl
resource "aws_lb_listener" "http" {
  port     = 80
  protocol = "HTTP"

  default_action {
    type = var.certificate_arn != "" ? "redirect" : "forward"

    # Redirects to HTTPS when certificate exists
    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}
```

**Recommendation**: Always configure `certificate_arn` variable in production to enable HTTPS-only access.

## Summary

All tfsec findings have been addressed:

| Finding | Status | Action Taken |
|---------|--------|--------------|
| IMDS tokens not required | ✅ FIXED | Added `metadata_options` with `http_tokens = "required"` |
| Public egress allowed | ✅ ACCEPTED | Required for functionality, documented |
| Public ingress on ALB | ✅ ACCEPTED | Required for web access, documented |
| Public IP on subnets | ✅ FIXED | Set `map_public_ip_on_launch = false` |
| ALB is public | ✅ ACCEPTED | Required for web access, documented |
| ALB doesn't drop invalid headers | ✅ FIXED | Added `drop_invalid_header_fields = true` |
| HTTP listener used | ✅ ACCEPTED | Auto-redirects to HTTPS when cert configured |
| IAM policy wildcards | ✅ FIXED | Scoped policies to specific resources |
| RDS Performance Insights encryption | ✅ FIXED | Added KMS key for encryption |
| RDS storage not encrypted | ✅ FIXED | Enabled `storage_encrypted = true` |
| S3 not using customer key | ✅ FIXED | Using KMS customer-managed key |

**Compliance**: All mandatory security controls are implemented. Intentional exceptions are documented with justifications and mitigations.
