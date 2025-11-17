# VPC (Terraform + GitHub Actions + AWS)

This project demonstrates how to build and deploy a secure, production ready **VPC** on AWS using **Terraform (Infrastructure as Code)** and **GitHub Actions CI/CD pipeline** with **OIDC authentication**.

The VPC includes public and private subnets, Internet Gateway (IGW), NAT Gateway, Network ACLs, Security Groups, and proper routing to support multi-tier applications.

## Architecture Overview

**High-Level Flow:**

1. **Terraform** → Declaratively defines infrastructure (IaC)
2. **S3 + DynamoDB** → Remote Terraform state locking
3. **GitHub Actions** → CI/CD automation using OIDC (no static AWS keys)
4. **Networking Resources** → VPC, Subnets, Route Tables, NACLs, IG, NAT Gateway, SGs
5. **Systems Manager (SSM)** → Parameter Store for configuration management
6. **CloudWatch** → VPC Flow Logs

See [`Architecture.md`](./docs/Architecture.md) for diagrams and details.

---

## Respository Structure

```bash
├── .github/workflows/                          # GitHub Actions pipelines
│   ├── destroy.yml
│   ├── vpc.yml
├── .tfsec/
├── docs/
│   ├── Architecture.md                         # Architecture documentation
│   └── vpc-diagram.png                         # Architecture diagram
│   └── ADRs/                                   # Architecture Decision Records
├── infrastructure
│   ├── env/                                    # configuration for each environment
│   │   ├── dev.yml
│   │   ├── test.yml
│   │   └── prod.yml
│   ├── modules
│   │   ├── dynamodb/
│   │   ├── iam/
│   │   ├── vpc/
│   │   └── s3/
│   ├── main.tf
│   ├── provider.tf
│   ├── remote-state.tf
│   ├── variables.tf
└── README.md

```

## Prerequisites

- **AWS Account / IAM User or Role** with permissions for:
  - S3 (Terraform backend)
  - DynamoDB (State locking)
  - IAM (OIDC provider + scoped execution roles)
  - SSM (Parameter storage)
- **Bootstrap Role / Admin User** with **least privilege** for the above resources
- **GitHub Environment Secrets** per environment:
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (only for destroy)
- **GitHub Repository Secrets**:
  - `AWS_ACCOUNT_ID` (used in all workflows)
  - `PERSONAL_IP` (used in all workflows)[to allow ssh access from your IP]
- **Terraform v1.12.2+**

## Setup

**Step 1: Bootstrap Remote Backend**
I have a separate workflow that is only ran once (from the Terraform-GLOBAL repo).

**This creates:**

- S3 bucket (Terraform remote state)
- DynamoDB table (state locking)
- OIDC provider + IAM roles for dev, test, prod
- SSM Parameters storing backend config

**Step 2: Deploy VPC**

Run the vpc.yml workflow for target environment (branch).

**This creates:**

- AWS VPC
- Public / Private Subnets (2 Public / 2 Private; 1 per AZ)
- Public / Private Route Tables
- Internet Gateway (IPV4)
- Elastic IP (1 per NAT)
- NAT Gatways (1 per AZ in prod; 1 total in dev / test)
- Network Access Control Lists (NACLs)[1 Public / 1 Private]
- Security Groups (SGs)[Application Load Balancer, App, Database, Bastion Host]

## CI/CD Environments

This project uses GitHub Actions with environment level isolation and deployment protection for each stage.

| Environment | Branch | AWS Context | Authentication  | Deployment Type      | Protection level               | Purpose            |
| ----------- | ------ | ----------- | --------------- | -------------------- | ------------------------------ | ------------------ |
| `dev`       | `dev`  | Development | OIDC → IAM Role | Automatic (on push)  | Auto deploy                    | Deploys VPC (Dev)  |
| `test`      | `test` | Staging     | OIDC → IAM Role | Automatic (on push)  | Auto deploy                    | Deploys VPC (Test) |
| `prod`      | `main` | Production  | OIDC → IAM Role | Manuel (on approval) | Protected — reviewers required | Deploys VPC (Prod) |

Each environment has its own **GitHub Environment**, **secrets** and **Terraform remote backend**, ensuring strict separation of state, credentials and deployment permissions.

## CI/CD Workflow Summary

1. Deploy per environment → vpc.yml
2. Destroy environment → destroy.yml

- On Push:

  - Authenticates via OIDC
  - Runs lint / tests / security checks on terraform configuration (fmt, validate, lint, tfsec)
  - Executes terraform apply (auto-approved for dev/test)

- On pull requests:

  - Runs terraform plan for pre-deployment review

## Documentation

- Architecture.md → diagrams & design
- ADRs → architectural decisions

## Testing

- CI validates Terraform formatting, syntax, and plans

## Security Best Practices

- No static AWS credentials after bootstrap
- Environment level OIDC roles → least privilege IAM
- Encrypted S3 state + DynamoDB locking
- Backend and config stored securely in SSM
- GitHub Secrets per environment
- Terraform Security checks

## Observability

- VPC Flow Logs (future improvement).
- CloudWatch metrics for NAT Gateway and network traffic.

## Cost Optimization

| Service             | Optimization                 | Notes                                                                                        |
| ------------------- | ---------------------------- | -------------------------------------------------------------------------------------------- |
| **NAT Gateway**     | Environment based scaling    | Single NAT for dev/test ($45/month), one per AZ for prod ($90/month) - saves 50% in non-prod |
| **DynamoDB**        | Pay-per-request              | On demand billing for state locking - minimal cost for infrequent operations                 |
| **S3**              | Standard storage + lifecycle | Terraform state files use standard storage with versioning - consider IA after 30 days       |
| **VPC Flow Logs**   | CloudWatch integration       | Flow logs enabled but consider S3 destination for long term storage (90% cost reduction)     |
| **Security Groups** | Consolidated rules           | Modular SG design reduces duplicate rules and simplifies management                          |
| **Subnets**         | Right sized CIDR blocks      | /24 subnets (254 IPs each) prevent over provisioning while maintaining growth capacity       |

## Tech Stack

- **Infrastructure**: Terraform (IaC)
- **CI/CD**: GitHub Actions + OIDC Auth
- **Networking**: VPC
- **Database**: DynamoDB (state locking)
- **Storage**: S3 (state file)
- **Observability**: CloudWatch
- **Config Management**: SSM Parameter Store

## Future Improvements

- Expand ADRs (network segmentation, high availability)
- Add logging
- Integrate with monitoring (Grafana, Prometheus)
- Add Transit Gateway for multi-VPC setups

## See also

- [Terraform Serverless API](https://github.com/dtolbertcooke/Terraform-Serverless-API/)

## Author

Doug Tolbert-Cooke  
Cloud & DevOps Engineer
