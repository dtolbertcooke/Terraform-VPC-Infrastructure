# Remote State Backend with S3 & DynamoDB using modules
# Github OIDC provider

# state bucket
module "s3_backend" {
  source       = "../../modules/s3"
  bucket_name  = var.state_bucket_name
  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner
}

# locking table
module "dynamodb_backend" {
  source              = "../../modules/dynamodb"
  dynamodb_table_name = var.dynamodb_table_name
  environment         = var.environment
  project_name        = var.project_name
  owner               = var.owner
}

# OIDC policy to be used by all (dev, test, prod) github oidc roles
resource "aws_iam_policy" "github_actions_policy" {
  name = "github-oidc-role-terraform-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "TerraformS3StateBucketAccess",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy"
        ],
        "Resource" : [
          "arn:aws:s3:::${module.s3_backend.bucket_name}",
          "arn:aws:s3:::${module.s3_backend.bucket_name}/*"
        ]
      },
      {
        "Sid" : "TerraformDynamoDBStateLockAccess",
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ],
        "Resource" : "arn:aws:dynamodb:${var.region}:${var.aws_account_id}:table/${module.dynamodb_backend.dynamodb_table_name}"
      },
      {
        "Sid" : "TerraformNetworkingAccess",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:DescribeSubnets",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:DescribeNatGateways",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateNetworkAcl",
          "ec2:DeleteNetworkAcl",
          "ec2:CreateNetworkAclEntry",
          "ec2:DeleteNetworkAclEntry",
          "ec2:DescribeNetworkAcls",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags",
          "ec2:ModifyVpcAttribute",
          "ec2:AllocateAddress",
          "ec2:DescribeAddresses",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcClassicLinkDnsSupport",
          "ec2:DescribeVpcClassicLink",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeSecurityGroupRules",
          "ec2:ReplaceNetworkAclAssociation",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DisassociateAddress",
          "ec2:ReleaseAddress",
          "ec2:DescribeAddressesAttribute"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "TerraformIAMAccess",
        "Effect" : "Allow",
        "Action" : [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:ListPolicies",
          "iam:PassRole"
        ],
        "Resource" : [
          "arn:aws:iam::${var.aws_account_id}:role/github-oidc-role"
        ]
      },
      {
        "Sid" : "TerraformAssumeRole",
        "Effect" : "Allow",
        "Action" : ["sts:AssumeRole"],
        "Resource" : "arn:aws:iam::${var.aws_account_id}:role/github-oidc-role"
      },
      {
        Sid    = "AllowSSMGetParameters"
        Effect = "Allow"
        Action = ["ssm:GetParameters", "ssm:GetParameter"]
        Resource = [
          "arn:aws:ssm:${var.region}:${var.aws_account_id}:parameter/tf/*/backend/bucket",
          "arn:aws:ssm:${var.region}:${var.aws_account_id}:parameter/tf/*/backend/region",
          "arn:aws:ssm:${var.region}:${var.aws_account_id}:parameter/tf/*/backend/table"
        ]
      }
    ]
    }
  )
}

# create github oidc provider & 3 roles for terraform in all environments (dev, test, prod)
module "github-oidc-dev" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "2.2.1"

  create_oidc_provider      = true # only create provider once
  create_oidc_role          = true
  role_name                 = "github-oidc-role-dev"
  github_thumbprint         = "6938fd4d98bab03faadb97b34396831e3780aea1"
  oidc_role_attach_policies = [aws_iam_policy.github_actions_policy.arn] # attach oidc policy created above
  repositories              = ["dtolbertcooke/Portfolio-Project-1:environment:dev"]
}
module "github-oidc-test" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "2.2.1"

  create_oidc_provider      = false # ony create provider once
  create_oidc_role          = true
  role_name                 = "github-oidc-role-test"
  github_thumbprint         = "6938fd4d98bab03faadb97b34396831e3780aea1"
  oidc_role_attach_policies = [aws_iam_policy.github_actions_policy.arn] # attach oidc policy created above
  repositories              = ["dtolbertcooke/Portfolio-Project-1:environment:test"]
  oidc_provider_arn         = module.github-oidc-dev.oidc_provider_arn
}
module "github-oidc-prod" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "2.2.1"

  create_oidc_provider      = false # only create provider once
  create_oidc_role          = true
  role_name                 = "github-oidc-role-prod"
  github_thumbprint         = "6938fd4d98bab03faadb97b34396831e3780aea1"
  oidc_role_attach_policies = [aws_iam_policy.github_actions_policy.arn] # attach oidc policy created above
  repositories              = ["dtolbertcooke/Portfolio-Project-1:environment:prod"]
  oidc_provider_arn         = module.github-oidc-dev.oidc_provider_arn
}

