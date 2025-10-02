module "dev_vpc" {
  source       = "../../modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  azs          = var.azs
  owner        = var.owner
  personal_ip  = var.personal_ip
}