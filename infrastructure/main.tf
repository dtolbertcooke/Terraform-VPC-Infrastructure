locals {
  config = yamldecode(file("${path.module}/env/${var.environment}.yml"))
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = local.config.project_name
  environment  = var.environment
  vpc_cidr     = local.config.vpc_cidr
  azs          = local.config.azs
  owner        = local.config.owner
  personal_ip  = var.personal_ip
}
