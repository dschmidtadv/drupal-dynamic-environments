# GitHub Actions Workflows

## Quick Reference

### 🔄 Terraform Plan
**File:** `terraform-plan.yml`
**Trigger:** Pull Request
**Purpose:** Validate and preview infrastructure changes

**What it does:**
- ✅ Format check
- ✅ Validation
- ✅ Plan generation
- 💬 Comments plan on PR

---

### 🚀 Terraform Apply
**File:** `terraform-apply.yml`
**Trigger:** Push to main / Manual
**Purpose:** Deploy base infrastructure

**What it does:**
- 🔨 Deploy to AWS
- 📊 Output infrastructure details
- ✅ Requires approval (production environment)

**Manual options:**
- `apply` - Deploy infrastructure
- `destroy` - Destroy infrastructure

---

### 🌿 Branch Environment
**File:** `branch-environment.yml`
**Trigger:** Manual only
**Purpose:** Create/destroy branch-specific Drupal environments

**Inputs:**
- `branch_name` - Environment name (e.g., "uat", "feature-auth")
- `action` - `deploy` or `destroy`
- `listener_priority` - ALB rule priority (0 = auto)

**What it does:**
- 🏗️ Generate Terraform module config
- 🚀 Deploy ECS service
- 🔗 Register with ALB
- 📝 Commit configuration file
- 🌐 Output environment URL

---

### ✅ Compliance Check
**File:** `compliance-check.yml`
**Trigger:** PR / Push / Weekly / Manual
**Purpose:** Validate governance rules and security

**What it checks:**
- Private subnet enforcement
- IAM role separation
- Secrets Manager usage
- Circuit breakers
- Traffic-based scaling
- Security scan (tfsec)

---

## Workflow Order

### Initial Deployment
1. **Terraform Plan** (automatic on PR)
2. **Terraform Apply** (automatic on merge)
3. **Branch Environment** (manual for each environment)

### Ongoing Operations
1. Make changes → PR → **Terraform Plan**
2. Review plan → Merge → **Terraform Apply**
3. Create environments → **Branch Environment** (deploy)
4. Remove environments → **Branch Environment** (destroy)

### Monitoring
- **Compliance Check** runs automatically weekly
- Run manually for on-demand validation

---

## Usage Examples

### Create UAT Environment
```
Actions → Deploy Branch Environment → Run workflow
- Branch name: uat
- Action: deploy
- Priority: 0
```

### Destroy Feature Environment
```
Actions → Deploy Branch Environment → Run workflow
- Branch name: feature-auth
- Action: destroy
```

### Manual Infrastructure Deployment
```
Actions → Terraform Apply → Run workflow
- Action: apply
```

### Run Compliance Check
```
Actions → Compliance Check → Run workflow
```

---

## Required Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM role for GitHub Actions OIDC |

## Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS deployment region |

---

## Status Badges

Add to your README.md:

```markdown
![Terraform Plan](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/terraform-plan.yml/badge.svg)
![Terraform Apply](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/terraform-apply.yml/badge.svg)
![Compliance Check](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/compliance-check.yml/badge.svg)
```

---

## Troubleshooting

### Workflow fails with "Error assuming role"
➡️ Check `AWS_ROLE_ARN` secret and IAM trust policy

### "Backend initialization failed"
➡️ Configure S3 backend in `main.tf` (see `GITHUB_ACTIONS_SETUP.md`)

### Branch environment deployment hangs
➡️ Check ECS service status and CloudWatch Logs

### Compliance check fails
➡️ Review COMPLIANCE.md and fix reported issues

---

For detailed setup instructions, see [GITHUB_ACTIONS_SETUP.md](../../GITHUB_ACTIONS_SETUP.md)
