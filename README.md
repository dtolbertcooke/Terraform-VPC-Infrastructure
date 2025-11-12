# VPC (Terraform + GitHub Actions + AWS)

This project demonstrates how to build and deploy a secure, production ready VPC on AWS using Infrastructure as Code (Terraform) and a CI/CD pipeline (GitHub Actions with OIDC).

The VPC includes public and private subnets, Internet Gateway (IGW), NAT Gateway, Network ACLs, Security Groups, and proper routing to support multi-tier applications.

---

## Architecture

**High-Level Flow:**

1. **Terraform** → IaC to provision infrastructure
2. **Remote Backend** → Terraform state stored in **S3**, with state locking via **DynamoDB**
3. **CI/CD** → GitHub Actions with **OIDC role assumption** (no static AWS creds)
4. **Networking Resources** → VPC, subnets, route tables, NACLs, IG, NAT Gateway, SGs

See [`Architecture.md`](./Architecture.md) for diagrams and details.

---

## Respository Structure

```bash
.
├── .github/
│   └── workflows/                        # GitHub Actions pipelines
│       └── ci-cd.yml
├── docs
│   ├── ADRs.md                         # Architecture Decision Records
│   └── architecture-diagram.png # Architecture diagram
├── infrastructure
│   ├── backend
│   │   └── global                      # configuration for each environment
│   │       ├── global-infra.tfvars
│   │       ├── global.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── environments                    # configuration for each environment
│   │   └── dev
│   │       ├── dev.tfvars
│   │       ├── dev.tf
│   │       ├── remote-state.tf
│   │       └── variables.tf
│   │   └── test
│   │       ├── test.tfvars
│   │       ├── test.tf
│   │       ├── remote-state.tf
│   │       └── variables.tf
│   │   └── prod
│   │       ├── prod.tfvars
│   │       ├── prod.tf
│   │       ├── remote-state.tf
│   │       └── variables.tf
│   ├── modules
│   │   ├── dynamodb
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── iam
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── vpc
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   └── s3
│   │       ├── main.tf
│   │       ├── outputs.tf
│   │       └── variables.tf
│   ├── provider.tf
│   └── variables.tf
├── Architecture.md                       # Architecture documentation
└── README.md

```

## Prerequisites

- AWS Account with permissions to create IAM, S3, DynamoDB, VPC, subnets, gateways, and security rules.
- Terraform v1.12.2+
- Repo level secrets for GitHub Actions

## Setup

1. Bootstrap Remote Backend

- run global-bootstrap.yml workflow

**This creates:**

- S3 bucket for Terraform state
- S3 bucket for lambda source code (one per environment)
- DynamoDB table for state locking
- IAM role/policy/provider for GitHub OIDC

2. Deploy VPC

- run vpc.yml workflow

## CI/CD Workflow

1. Manually run global-bootstrap.yml **once** to initialize backend.
2. Build terraform network infrastructure for vpc

- On push to dev:

  - GitHub Actions authenticates to AWS via OIDC
  - Runs tests on terraform configuration
  - On approval (global-infra / main branch) → terraform apply

- On pull requests:

  - Runs plans for review

Workflow config: .github/workflows/vpc.yml

## Documentation

- Architecture.md → diagrams & design
- ADRs → key architectural decisions

## Testing

- Pipeline validates Terraform (terraform fmt, validate, plan).

## Security Best Practices

- No static AWS credentials → OIDC used for GitHub Actions.
- Least privilege IAM roles.
- Remote state with locking (S3 + DynamoDB).
- Parameters stored in AWS SSM Parameter Store
- Secrets stored in GitHub Actions secrets.

## Observability

- VPC Flow Logs (future improvement).
- CloudWatch metrics for NAT Gateway and network traffic.

## Future Improvements

- Add VPC Flow Logs to S3 / CloudWatch Logs.
- Expand ADRs (network segmentation, high availability).
- Add logging via Kinesis + CloudWatch.
- Integrate with monitoring (Grafana, Prometheus).
- Add Transit Gateway for multi-VPC setups.
