# Creates reference to Main VPC without attempting to manage it's state
data "aws_vpc" "main_corp_vpc" {
  id = "${var.corp_vpc_id}"
}

data "aws_caller_identity" "current" {}

resource "aws_vpc_peering_connection" "pcx" {
  vpc_id        = "${module.vpc.vpc_id}"
  peer_vpc_id   = "${data.aws_vpc.main_corp_vpc.id}"
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  auto_accept   = true

  tags {
    Name = "TF-Main-PCX"
  }
}

data "aws_route_table" "corp_rt_1" {
  route_table_id = "${var.corp_rt_id_1}"
}

resource "aws_route" "corp_to_tf_1" {
  route_table_id            = "${data.aws_route_table.corp_rt_1.id}"
  destination_cidr_block    = "${module.vpc.cidr}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.pcx.id}"
}

resource "aws_route" "tf_to_corp_1" {
  count                     = "${length(var.vpc_subnets) + length(var.vpc_private_app_subnets)}"
  route_table_id            = "${element(concat(module.vpc_route_tables.route_tables, module.vpc_route_tables_private_app_subnets.route_tables), count.index)}"
  destination_cidr_block    = "${data.aws_vpc.main_corp_vpc.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.pcx.id}"
}

# and the devtools peering so Jenkins can access RDS databases in the VPC

data "aws_vpc" "devtools_vpc" {
  id = "${var.devtools_vpc_id}"
}

resource "aws_vpc_peering_connection" "devtools_pcx" {
  vpc_id        = "${module.vpc.vpc_id}"
  peer_vpc_id   = "${data.aws_vpc.devtools_vpc.id}"
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  auto_accept   = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags {
    Name = "TF-DevTools-PCX"
  }
}

data "aws_route_table" "devtools_vpc_rt_jenkins_agents" {
  route_table_id = "${var.devtools_vpc_rt_jenkins_agents}"
}

resource "aws_route" "devtools_agents_to_tf" {
  route_table_id            = "${data.aws_route_table.devtools_vpc_rt_jenkins_agents.id}"
  destination_cidr_block    = "${module.vpc.cidr}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.devtools_pcx.id}"
}

resource "aws_route" "tf_to_devtools_agents" {
  count                     = "${length(var.vpc_subnets) + length(var.vpc_private_app_subnets) + length(var.vpc_private_rds_subnets)}"
  route_table_id            = "${element(concat(module.vpc_route_tables.route_tables, module.vpc_route_tables_private_app_subnets.route_tables, module.vpc_route_tables_private_rds_subnets.route_tables), count.index)}"
  destination_cidr_block    = "${data.aws_vpc.devtools_vpc.cidr_block}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.devtools_pcx.id}"
}
