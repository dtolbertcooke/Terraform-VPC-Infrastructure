locals {
  config = yamldecode(file("${path.module}/env/${var.environment}.yml"))
}

module "vpc" {
  source          = "./modules/vpc"
  project_name    = local.config.project_name
  environment     = var.environment
  vpc_cidr        = local.config.vpc_cidr
  azs             = local.config.azs
  public_subnets  = local.config.public_subnets
  private_subnets = local.config.private_subnets
  owner           = local.config.owner
  personal_ip     = var.personal_ip
}
