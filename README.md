# aws-gitops-platform

Production-ready GitOps portfolio project that deploys a containerized FastAPI service to AWS ECS Fargate from GitHub Actions, with infrastructure managed through Terraform modules.

## Architecture (ASCII)

```
Developer Push/PR
      |
      v
GitHub Actions (CI/CD with OIDC)
      |
      +--> CI: pytest + terraform validate + build + push image
      |
      v
Amazon ECR (versioned images)
      |
      v
CD Pipeline
  |- auto deploy -> STAGING ECS Service
  |- manual approval -> PRODUCTION ECS Service
      |
      v
Application Load Balancer (HTTP -> HTTPS)
      |
      v
ECS Fargate Tasks (private subnets)
      |
      +--> Application Auto Scaling (CPU/Memory target tracking)
      +--> Secrets Manager (runtime secret injection)
      +--> CloudWatch Logs (/ecs/...)
      +--> CloudWatch Alarms (CPU/Memory thresholds)

Networking:
VPC
|- Public subnets: ALB, NAT
|- Private subnets: ECS tasks
|- IGW + NAT for controlled outbound traffic

Terraform State:
S3 backend (state files per env) + DynamoDB lock table
```

## Project structure

```
aws-gitops-platform/
├── app/
│   ├── main.py
│   ├── requirements.txt
│   ├── tests/
│   │   └── test_app.py
│   └── Dockerfile
├── infra/
│   ├── modules/
│   │   ├── networking/
│   │   ├── ecr/
│   │   ├── ecs/
│   │   └── alb/
│   └── envs/
│       ├── staging/
│       └── production/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
└── README.md
```

## Prerequisites

- AWS account with permission to manage ECS, ECR, ALB, VPC, IAM, Secrets Manager, S3, DynamoDB
- GitHub repository with Actions enabled
- Terraform `~> 1.7`
- AWS CLI v2
- Docker
- ACM certificate in the target AWS region for your domain

## Application endpoints

- GET /health: liveness probe for ALB and ECS health checks
- GET /ready: readiness probe for rolling deployments that returns 503 when required secrets are missing
- GET /version: current application version from APP_VERSION
- GET /info: runtime metadata (service, version, environment, region, git SHA, hostname)
- GET /config: sanitized runtime configuration without exposing secret values
- GET /diagnostics: deployment diagnostics with uptime and missing required secret names
- GET /docs: OpenAPI UI

## Step-by-step setup

1. Bootstrap remote Terraform state backend (once per account/region).

```bash
aws s3 mb s3://aws-gitops-platform-tfstate --region us-east-1
aws s3api put-bucket-versioning --bucket aws-gitops-platform-tfstate --versioning-configuration Status=Enabled
aws dynamodb create-table \
  --table-name aws-gitops-platform-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

2. Create Secrets Manager secrets and note their ARNs.

```bash
aws secretsmanager create-secret --name staging/app/api-key --secret-string '{"value":"replace-me"}'
aws secretsmanager create-secret --name production/app/api-key --secret-string '{"value":"replace-me"}'
```

3. Configure staging Terraform variables in `infra/envs/staging`.

Example values to include in `terraform.tfvars`:

```hcl
vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]
certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
secrets = {
  API_KEY = "arn:aws:secretsmanager:us-east-1:123456789012:secret:staging/app/api-key-xxxxx"
}

enable_autoscaling        = true
autoscaling_min_capacity  = 1
autoscaling_max_capacity  = 3
autoscaling_cpu_target    = 60
autoscaling_memory_target = 75

enable_service_alarms             = true
alarm_cpu_utilization_threshold   = 80
alarm_memory_utilization_threshold = 85
alarm_evaluation_periods          = 2
alarm_period_seconds              = 60
alarm_actions                     = ["arn:aws:sns:us-east-1:123456789012:staging-alerts"]
```

4. Configure production Terraform variables in `infra/envs/production`.

Example values to include in `terraform.tfvars`:

```hcl
vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]
certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
secrets = {
  API_KEY = "arn:aws:secretsmanager:us-east-1:123456789012:secret:production/app/api-key-yyyyy"
}

enable_autoscaling        = true
autoscaling_min_capacity  = 2
autoscaling_max_capacity  = 6
autoscaling_cpu_target    = 60
autoscaling_memory_target = 75

enable_service_alarms             = true
alarm_cpu_utilization_threshold   = 80
alarm_memory_utilization_threshold = 85
alarm_evaluation_periods          = 2
alarm_period_seconds              = 60
alarm_actions                     = ["arn:aws:sns:us-east-1:123456789012:production-alerts"]
```

5. Deploy infrastructure for each environment.

```bash
cd infra/envs/staging
terraform init
terraform plan
terraform apply

cd ../production
terraform init
terraform plan
terraform apply
```

6. Create GitHub OIDC IAM roles (recommended separate roles for staging and production), trust policy principal:

- Federated principal: `arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- Subject condition: `repo:Fabdev10/aws-gitops-platform:*`

Attach least-privilege policies needed for ECR push and ECS deploy operations.

7. Configure repository variables in GitHub (`Settings > Secrets and variables > Actions > Variables`).

Required variables:

- `AWS_REGION`
- `ECR_REPOSITORY`
- `AWS_GITHUB_OIDC_ROLE_ARN_STAGING`
- `AWS_GITHUB_OIDC_ROLE_ARN_PRODUCTION`
- `ECS_CLUSTER_STAGING`
- `ECS_SERVICE_STAGING`
- `ECS_CLUSTER_PRODUCTION`
- `ECS_SERVICE_PRODUCTION`
- `ECS_CONTAINER_NAME` (default `app`)

8. Enable manual approval for production.

- In GitHub: `Settings > Environments > production`
- Add required reviewers
- The `deploy-production` job in `cd.yml` waits for approval

9. Verify deployment.

- CI runs on pull requests
- CD runs on merge/push to `main`
- Check ALB DNS outputs from Terraform and test:

```bash
curl https://<alb-dns>/health
curl https://<alb-dns>/ready
curl https://<alb-dns>/version
curl https://<alb-dns>/info
```

## Local development

Run the app locally:

```bash
cd app
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
```

Optional runtime variables:

- `APP_ENV`: logical environment name shown by the API
- `APP_VERSION`: release version exposed by `/version`
- `AWS_REGION`: region included in runtime metadata
- `GIT_SHA`: commit identifier exposed by `/info` and `/diagnostics`
- `LOG_LEVEL`: sanitized setting returned by `/config`
- `REQUIRED_SECRETS`: comma-separated env var names that must exist for `/ready` to return 200

Run test suite:

```bash
pytest -q app/tests
```

## CI quality gates

- Python tests run via pytest against API endpoints
- Terraform formatting check runs on both staging and production stacks
- Terraform validation runs with backend disabled to catch configuration regressions early
- Docker build and ECR push run only after all checks pass

## Reliability features

- ECS service autoscaling via target tracking policies on CPU and memory
- CloudWatch alarms for high ECS CPU and memory utilization
- Alarm actions configurable with SNS topics or other supported integrations

## Notes

- ECS tasks run in private subnets and receive traffic only via ALB.
- Secrets are not baked into images; they are injected at runtime from Secrets Manager.
- CloudWatch log group retention is configurable in the ECS module.
- State is isolated by backend key: `staging/terraform.tfstate` and `production/terraform.tfstate`.
