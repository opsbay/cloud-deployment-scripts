module "vpc" {
  source                = "./modules/vpc"
  name                  = "main"
  cidr                  = "${var.vpc_cidr}"
  private_app_subnets   = ["${var.vpc_private_app_subnets}"]
  private_rds_subnets   = ["${var.vpc_private_rds_subnets}"]
  private_cache_subnets = ["${var.vpc_private_cache_subnets}"]
  subnets               = ["${var.vpc_subnets}"]
  azs                   = ["${var.vpc_azs}"]
  peer_vpc_cidr_block   = "${data.aws_vpc.devtools_vpc.cidr_block}"
  nat_gw_eip_allocs     = ["${var.nat_gw_eip_allocs}"]
}

module "vpc_route_tables" {
  source                        = "./modules/vpc_route_tables"
  name                          = "main_route_tables"
  vpc_id                        = "${module.vpc.vpc_id}"
  subnets                       = "${module.vpc.subnets}"
  internet_gateway_id           = "${module.vpc.internet_gateway_id}"
  create_internet_gateway_route = "1"

  propagating_vgws = [
    "${module.vpn.vgw_id}",
  ]
}

module "vpc_route_tables_private_app_subnets" {
  source                   = "./modules/vpc_route_tables"
  name                     = "private_app_subnets_route_tables"
  vpc_id                   = "${module.vpc.vpc_id}"
  subnets                  = "${module.vpc.private_app_subnets}"
  nat_gateway_ids          = "${module.vpc.nat_gateway_ids}"
  create_nat_gateway_route = "1"

  propagating_vgws = [
    "${module.vpn.vgw_id}",
  ]
}

module "vpc_route_tables_private_rds_subnets" {
  source  = "./modules/vpc_route_tables"
  name    = "private_rds_subnets_route_tables"
  vpc_id  = "${module.vpc.vpc_id}"
  subnets = "${module.vpc.private_rds_subnets}"

  propagating_vgws = [
    "${module.vpn.vgw_id}",
  ]
}

module "vpc_route_tables_private_cache_subnets" {
  source  = "./modules/vpc_route_tables"
  name    = "private_cache_subnets_route_tables"
  vpc_id  = "${module.vpc.vpc_id}"
  subnets = "${module.vpc.private_cache_subnets}"

  propagating_vgws = [
    "${module.vpn.vgw_id}",
  ]
}
