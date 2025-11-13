# VPC with public/private subnets, NAT, security groups, etc.

# VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name            = "${var.project_name}-${var.environment}-vpc"
  cidr            = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

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
  enable_nat_gateway     = true
  single_nat_gateway     = var.environment == "dev" || var.environment == "test" ? true : false # one NAT gateway for dev/test
  one_nat_gateway_per_az = var.environment == "dev" || var.environment == "test" ? false : true # one NAT gateway per AZ for prod

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

