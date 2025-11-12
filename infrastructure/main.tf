locals {
  config = yamldecode(file("${path.module}/env/${var.environment}.yml"))
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = var.azs
  owner        = var.owner
  personal_ip  = var.personal_ip
}
