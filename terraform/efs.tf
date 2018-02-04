module "efs" {
  source  = "./modules/efs"
  subnets = ["${module.vpc.private_app_subnets}"]
}
