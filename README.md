# DevOps Challenge — Production-Ready Application Deployment

A fully automated, production-grade deployment of a Node.js microservice on AWS EC2, built with Terraform, GitHub Actions, Docker, and CloudWatch.

---

## Architecture Overview

```
Developer → GitHub → GitHub Actions → ECR → App EC2
                                           ↓
                                  AWS CloudWatch (Logs, Metrics, Alarms)
```

### Full Diagram

See [`docs/architecture.mermaid`](docs/architecture.mermaid) — render at [mermaid.live](https://mermaid.live) or view directly on GitHub.

### Components

| Component | Technology | Purpose |
|---|---|---|
| Application | Node.js 18 / Express | REST microservice with `/`, `/health`, `/metrics` endpoints |
| Containerisation | Docker (multi-stage build) | Reproducible, minimal production image |
| Infrastructure | Terraform (modular) | VPC, EC2, ECR, IAM, CloudWatch |
| CI/CD | GitHub Actions | 3-job pipeline: Test → Build & Push → Deploy |
| Image Registry | Amazon ECR | Private Docker registry with lifecycle policies |
| Monitoring | AWS CloudWatch | Structured logs, custom metrics, dashboard, alarms |

### AWS Resources Provisioned

- **VPC** — `10.0.0.0/16` with two public subnets across two AZs
- **Internet Gateway** + public route tables
- **EC2 — App Server** (`t4g.micro`) — runs the Dockerised application
- **Elastic IP** — stable public IP for the app instance
- **Security Group** — app traffic on port 3000; SSH restricted to your IP
- **IAM Role (EC2)** — least-privilege ECR pull + CloudWatch publish
- **IAM Role (GitHub Actions)** — OIDC-based, scoped to `main` branch of your repo; no long-lived keys
- **GitHub OIDC Provider** — one per AWS account; enables keyless auth from Actions
- **ECR Repository** — image scanning on push, lifecycle cleanup (keeps last 10 tagged)
- **CloudWatch Log Groups** — app logs (30 days), system logs (7 days)
- **CloudWatch Dashboard** — CPU, memory, network, log widgets
- **CloudWatch Alarms** — CPU > 80% and memory > 85%

---

## Repository Structure

```
damolak/
├── .github/
│   └── workflows/
│       └── deploy.yml            # GitHub Actions pipeline (3 jobs)
├── app/
│   ├── src/
│   │   └── index.js              # Express application
│   ├── tests/
│   │   └── app.test.js           # Jest unit + integration tests
│   └── package.json
├── terraform/
│   ├── main.tf                   # Root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── vpc/
│       ├── security_groups/
│       ├── ec2/                  # EC2 + EIP + CloudWatch agent bootstrap
│       ├── ecr/                  # ECR repo + lifecycle policy
│       ├── iam/                  # EC2 role + GitHub Actions OIDC role
│       └── cloudwatch/           # Log groups, dashboard, alarms
├── scripts/
│   ├── bootstrap-infra.sh        # Local helper: terraform init → plan → apply
│   └── deploy.sh                 # Deployment script (copied to EC2 by Actions)
├── docs/
│   └── architecture.mermaid
├── Dockerfile                    # Multi-stage: deps → test → production
├── docker-compose.yml            # Local development
└── .gitignore
```

---

## Prerequisites

| Tool | Min Version | Notes |
|---|---|---|
| Terraform | 1.6.0 | [Install](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | 2.x | Configured with a profile that can create VPCs, EC2, ECR, IAM resources |
| Docker | 24.x | Local development only |
| Node.js | 18.x | Local development only |
| EC2 Key Pair | — | Must already exist in your target AWS region |

---

## Deployment Steps

### 1. Fork & Clone

```bash
# Fork the repo on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/devops-challenge.git
cd devops-challenge
```

### 2. Configure Terraform Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` — at minimum set:

```hcl
key_pair_name = "your-existing-keypair"
allowed_ssh_cidr = "YOUR.IP.HERE/32"    # curl ifconfig.me
github_org  = "your-github-username"
github_repo = "devops-challenge"
```

### 3. Provision Infrastructure

```bash
bash scripts/bootstrap-infra.sh
```

This runs `terraform init`, `validate`, `plan`, and `apply`. Note the outputs at the end — you'll need them for the next step.

> ⏱ The EC2 instance bootstraps Docker and the CloudWatch agent via `user_data`. Allow **2–3 minutes** before deploying.

### 4. Add GitHub Repository Secrets

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret Name | Value | Where to get it |
|---|---|---|
| `AWS_REGION` | e.g. `us-east-1` | Your `terraform.tfvars` |
| `AWS_OIDC_ROLE_ARN` | `arn:aws:iam::...` | `terraform output github_actions_role_arn` |
| `ECR_REPO_URL` | `<account>.dkr.ecr.<region>.amazonaws.com/...` | `terraform output ecr_repository_url` |
| `APP_SERVER_IP` | App EC2 public IP | `terraform output app_public_ip` |
| `APP_EC2_SSH_KEY` | Contents of your `.pem` private key | Your local key file |

> **No AWS access keys are stored in GitHub.** The pipeline authenticates via OIDC — GitHub Actions exchanges a short-lived token for temporary AWS credentials scoped to your repo's `main` branch only.

### 5. Create a GitHub Environment (Optional but Recommended)

Go to **Settings → Environments → New environment** → name it `production`.

This unlocks the deployment approval gate in the workflow — the deploy job will pause for a manual approval before running.

### 6. Trigger the Pipeline

Push a commit to `main`:

```bash
git commit --allow-empty -m "chore: trigger initial deploy"
git push origin main
```

The pipeline will:

| Job | Steps |
|---|---|
| **test** | Install deps → run Jest tests with coverage |
| **build-and-push** | Build multi-stage Docker image → push `v<run>-<sha>` and `latest` to ECR |
| **deploy** | Copy `deploy.sh` to EC2 → SSH in → pull image → zero-wait restart → smoke-test `/health` |

### 7. Verify

```bash
# Replace with your app IP
APP_IP=$(cd terraform && terraform output -raw app_public_ip)

curl http://$APP_IP:3000/
curl http://$APP_IP:3000/health
curl http://$APP_IP:3000/metrics
```

Expected `/health`:
```json
{ "status": "healthy", "version": "v5-a1b2c3d", "environment": "production", ... }
```

---

## Local Development

```bash
cd app
npm install
npm test          # run tests
npm start         # start on :3000

# Or with Docker Compose (from project root)
docker-compose up --build
```

---

## CI/CD Pipeline Detail

```
push to main
    │
    ▼
┌─────────────────────┐
│  Job 1: test         │  Node 18 → npm ci → jest --ci --coverage
└──────────┬──────────┘
           │ (must pass)
    ▼
┌─────────────────────┐
│  Job 2: build-push   │  OIDC auth → docker build → push to ECR
└──────────┬──────────┘   tags: v<run>-<sha>  +  latest
           │
    ▼
┌─────────────────────┐
│  Job 3: deploy       │  SCP deploy.sh → SSH → pull → run → /health smoke test
└─────────────────────┘
```

PRs only run Job 1 (tests) — no image is pushed or deployed.

---

## Monitoring & Observability

### CloudWatch Logs

| Log Group | Retention | Content |
|---|---|---|
| `/devops-challenge/production/app` | 30 days | Container stdout/stderr (JSON structured) |
| `/devops-challenge/production/system` | 7 days | Bootstrap and OS logs |

Query recent errors:
```bash
aws logs filter-log-events \
  --log-group-name /devops-challenge/production/app \
  --filter-pattern "ERROR" \
  --region us-east-1
```

### CloudWatch Dashboard

AWS Console → CloudWatch → Dashboards → `devops-challenge-production`

Widgets: CPU utilisation · Memory used % · Network in/out · Live log tail

### Alarms

| Alarm | Threshold |
|---|---|
| `high-cpu` | CPU > 80% for 4 consecutive minutes |
| `high-memory` | Memory > 85% for 4 consecutive minutes |

Add an SNS topic to the alarms to receive email/Slack notifications.

---

## Design Decisions

### GitHub Actions over Jenkins
GitHub Actions is natively integrated with the repository — no separate CI server to provision, patch, or maintain. OIDC keyless auth is a first-class feature, and the workflow file lives alongside the code it builds. This eliminates a `t3.medium` Jenkins EC2 instance (cost saving) while delivering the same pipeline functionality.

### OIDC over Long-Lived AWS Keys
The pipeline never stores `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` in GitHub. Instead, GitHub's OIDC provider issues a short-lived JWT per run; AWS exchanges it for a temporary STS token valid for the duration of the job only. The IAM trust policy is scoped to the `main` branch of your specific repository — a stolen token from a PR cannot assume the role.

### Single App EC2 with EIP
EC2 with Docker provides full runtime visibility and keeps the architecture simple. An Elastic IP prevents the public address from changing on stop/start, which would otherwise break the GitHub Secret and SSH connectivity.

### Multi-Stage Dockerfile
Three stages — `deps` (prod deps), `test` (runs tests; blocks the image build on failure), `production` (minimal final image, non-root user). This means a broken test can never produce a deployable image.

### IMDSv2 Enforcement
`http_tokens = "required"` on the EC2 instance forces IMDSv2, mitigating SSRF-based credential theft from the instance metadata service.

### ECR Lifecycle Policy
Keeps the last 10 tagged images and expires untagged images after 1 day — prevents unbounded storage growth without losing recent rollback targets.

---

## Assumptions

1. An EC2 key pair already exists in the target region.
2. The AWS CLI is configured locally with permissions to create VPCs, EC2, ECR, IAM, and CloudWatch resources.
3. The GitHub OIDC provider (`token.actions.githubusercontent.com`) already exists in the AWS account. If not, uncomment the `aws_iam_openid_connect_provider` resource in `terraform/modules/iam/main.tf`.
4. `allowed_ssh_cidr` is set to a specific IP — not `0.0.0.0/0` — for any real deployment.

---

## Known Limitations & Future Improvements

| Area | Current | Improvement |
|---|---|---|
| **TLS/HTTPS** | HTTP only | Add ACM cert + ALB with HTTPS listener |
| **State backend** | Local | Uncomment S3 backend in `main.tf` for shared, locked remote state |
| **Zero-downtime deploys** | Brief stop/start gap | Blue/green with two EC2s behind an ALB |
| **Private networking** | App in public subnet | Move app to private subnet; ALB in public subnet |
| **Auto Scaling** | Single instance | ASG + ALB for HA and horizontal scale |
| **Notifications** | Alarms without actions | Wire CloudWatch alarms to SNS → email/Slack |
| **DNS** | Raw IP | Route 53 A record pointing to Elastic IP |
| **Multi-environment** | Single workspace | Terraform workspaces or separate `tfvars` per env |
| **Secrets management** | N/A (no app secrets) | AWS Secrets Manager injected at runtime |

---

## Cleanup

```bash
cd terraform
terraform destroy
```

> ECR images and CloudWatch log data persist after `terraform destroy`. Delete them manually in the console or add `force_delete = true` to the ECR resource.

---

## Author

Submitted as part of the DevOps Engineer Practical Challenge (96-hour assessment).
