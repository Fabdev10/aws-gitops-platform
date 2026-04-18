# aws-gitops-platform

Production-ready GitOps portfolio project that deploys a containerized FastAPI service to AWS ECS Fargate from GitHub Actions, with infrastructure managed through Terraform modules.

## Architecture (ASCII)

```
Developer Push/PR
      |
      v
GitHub Actions (CI/CD with OIDC)
      |
      +--> CI: test + build + push image
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
      +--> Secrets Manager (runtime secret injection)
      +--> CloudWatch Logs (/ecs/...)

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
curl https://<alb-dns>/version
```

## Notes

- ECS tasks run in private subnets and receive traffic only via ALB.
- Secrets are not baked into images; they are injected at runtime from Secrets Manager.
- CloudWatch log group retention is configurable in the ECS module.
- State is isolated by backend key: `staging/terraform.tfstate` and `production/terraform.tfstate`.
