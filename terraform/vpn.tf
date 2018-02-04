module "vpn" {
  source = "./modules/vpn"
  name   = "main"
  vpc_id = "${module.vpc.vpc_id}"
}

module "vpn-datacenter-sjc" {
  source                   = "./modules/vpn_connection"
  name                     = "datacenter-sjc"
  vpn_gateway_id           = "${module.vpn.vgw_id}"
  customer_gateway_address = "67.131.242.131"

  static_ip_prefix = ["${var.datacenter-sjc-static_ip_prefix}"]

  create_vpn_connection = "${var.aws-environment == "hobsons-naviancedev" ? 1 : 0}"
}

module "vpn-datacenter-iad" {
  source                   = "./modules/vpn_connection"
  name                     = "datacenter-iad"
  vpn_gateway_id           = "${module.vpn.vgw_id}"
  customer_gateway_address = "165.193.72.134"

  static_ip_prefix = ["${var.datacenter-iad-static_ip_prefix}"]

  create_vpn_connection = "${var.aws-environment == "hobsons-navianceprod" ? 1 : 0}"
}
