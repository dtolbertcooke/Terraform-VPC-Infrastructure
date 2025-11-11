# create a VPC with public/private subnets, NAT, security groups, etc.

locals {
  public_network_acls = {
    public_inbound_http = [
      {
        description = "allow inbound HTTP traffic"
        rule_number = 100
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    public_inbound_https = [
      {
        description = "allow inbound HTTPS traffic"
        rule_number = 110
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    public_inbound_ssh = [
      {
        description = "allow inbound SSH traffic"
        rule_number = 120
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = var.personal_ip
      },
    ]
    public_inbound_other = [
      {
        description = "deny all other inbound traffic"
        rule_number = 130
        rule_action = "deny"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
    public_outbound_all = [
      {
        description = "allow all outbound traffic"
        rule_number = 100
        rule_action = "allow"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
  }
  private_network_acls = {
    private_inbound_all = [
      {
        description = "allow inbound traffic from within the VPC"
        rule_number = 100
        rule_action = "allow"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = var.vpc_cidr
      }
    ],
    private_inbound_other = [
      {
        description = "deny all other inbound traffic"
        rule_number = 110
        rule_action = "deny"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ],
    private_outbound_all = [
      {
        description = "allow all outbound traffic"
        rule_number = 100
        rule_action = "allow"
        from_port   = 0
        to_port     = 0
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
  }
}

# create a VPC module
# tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
# Reason: Flow logs ARE enabled through module inputs, but tfsec cannot detect module created
#         CloudWatch Log Groups and IAM roles. This is a known false positive with vpc module v5.x.
# tfsec:ignore:aws-ec2-no-public-ingress-acl
# Reason: Public subnets must allow inbound traffic from the internet (HTTP/HTTPS) for an
#         internet-facing architecture. NACLs intentionally allow public ingress on required ports.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name            = "${var.project_name}-${var.environment}-vpc"
  cidr            = var.vpc_cidr
  azs             = var.azs
  public_subnets  = ["172.16.0.0/24", "172.16.1.0/24"]
  private_subnets = ["172.16.2.0/24", "172.16.3.0/24"]

  # Cloudwatch log group and IAM role will be created
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  # enable custom public NACL
  public_dedicated_network_acl = true
  public_inbound_acl_rules = concat(
    local.public_network_acls.public_inbound_https,
    local.public_network_acls.public_inbound_http,
    local.public_network_acls.public_inbound_ssh,
    local.public_network_acls.public_inbound_other
  )
  public_outbound_acl_rules = local.public_network_acls.public_outbound_all

  # enable custom private NACL
  private_dedicated_network_acl = true
  private_inbound_acl_rules     = concat(local.private_network_acls.private_inbound_all, local.private_network_acls.private_inbound_other)
  private_outbound_acl_rules    = local.private_network_acls.private_outbound_all

  # enable NAT Gateway
  # prod: create one NAT gateway per AZ for high availability and fault tolerance
  # dev: create a single NAT gateway for cost efficiency
  # currently set for 'prod'
  enable_nat_gateway     = true
  single_nat_gateway     = false # set to true for 'dev' environment
  one_nat_gateway_per_az = true  # set to false for 'dev' environment

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
  # name subnets
  public_subnet_tags_per_az = {
    for az in var.azs : az => { Name = "${var.project_name}-${var.environment}-public-subnet-${az}" }
  }

  private_subnet_tags_per_az = {
    for az in var.azs : az => { Name = "${var.project_name}-${var.environment}-private-subnet-${az}" }
  }
  # name route tables
  public_route_table_tags  = { Name = "${var.project_name}-${var.environment}-public-rt" }
  private_route_table_tags = { Name = "${var.project_name}-${var.environment}-private-rt" }
  # name IG
  igw_tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Security Groups:
# ALB SG: HTTP/HTTPS from 0.0.0.0/0
# App SG: allow only from ALB SG + intra-VPC SSH if needed
# DB SG: allow only MySQL/Aurora traffic from App SG
# Bastion SG: allow SSH from personal IP

# tfsec:ignore:aws-ec2-no-public-ingress-sgr
# Reason: The ALB is intentionally internet facing and requires inbound HTTP/HTTPS from 0.0.0.0/0.
# tfsec:ignore:aws-ec2-no-public-egress-sgr
# Reason: ALB outbound access to 0.0.0.0/0 is required for target health checks and interservice
#         communication. Outbound rules are aligned with AWS ALB defaults.
module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.1"

  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow inbound HTTP/HTTPS traffic"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow HTTP from anywhere"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow HTTPS from anywhere"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "tcp"
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

# tfsec:ignore:aws-ec2-no-public-egress-sgr
# Reason: Application instances require outbound internet access for OS updates, package downloads,
#         API calls, and logging/monitoring endpoints. Egress is intentionally unrestricted.
module "app_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Allow inbound traffic from ALB SG and Bastion Host SG"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "Allow HTTP from ALB SG"
      source_security_group_id = module.alb_sg.security_group_id
    },
    {
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      description              = "Allow HTTPS from ALB SG"
      source_security_group_id = module.alb_sg.security_group_id
    },
    {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      description              = "Allow SSH from Bastion Host SG"
      source_security_group_id = module.bastion_host_sg.security_group_id
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "tcp"
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

# Note: Bastion host ingress is restricted to a single trusted IP (var.personal_ip). Outbound SSH
#       access to application tier is intentional for administrative access.
module "bastion_host_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Allow inbound SSH from personal IP"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "Allow SSH from personal IP"
      cidr_blocks = var.personal_ip
    }
  ]

  egress_with_source_security_group_id = [
    {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      description              = "Allow SSH to App SG"
      source_security_group_id = module.app_sg.security_group_id
    }
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}
# tfsec:ignore:aws-ec2-no-public-egress-sgr
# Reason: DB instances require outbound traffic for logging, monitoring, backups, time sync,
#         and AWS control plane communication. Egress 0.0.0.0/0 is a standard RDS requirement.
module "db_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Allow inbound MySQL traffic from App SG"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      description              = "Allow MySQL from App SG"
      source_security_group_id = module.app_sg.security_group_id
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "tcp"
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

