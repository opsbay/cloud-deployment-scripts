# Parts of this module were inspired by
# https://github.com/terraform-community-modules/tf_aws_vpc
# which is licensed under the Apache License, Version 2.0.

# Which can be found here
# http://www.apache.org/licenses/LICENSE-2.0

resource "aws_vpc" "main" {
  cidr_block           = "${var.cidr}"
  enable_dns_hostnames = "${var.enable_hostnames}"
  enable_dns_support   = "${var.enable_dns}"

  tags {
    Name = "tf-${var.name}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "tf-${var.name}-gw"
  }
}

# Super useful NAT gateway tips cribbed from Charity Major's blog
# https://charity.wtf/2016/04/14/scrapbag-of-useful-terraform-tips/

resource "aws_nat_gateway" "main" {
  count         = "${length(var.nat_gw_eip_allocs)}"
  allocation_id = "${var.nat_gw_eip_allocs[count.index]}"
  subnet_id     = "${element(aws_subnet.subnets.*.id, count.index)}"
  depends_on    = ["aws_internet_gateway.main"]
}

resource "aws_subnet" "subnets" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${var.subnets[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.subnets)}"
  tags              = "${map("Name", format("tf-%s-subnet-public-%s", var.name, element(var.azs, count.index)))}"

  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"
}

resource "aws_subnet" "private_app_subnets" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${var.private_app_subnets[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.private_app_subnets)}"
  tags              = "${map("Name", format("tf-%s-subnet-private-app-%s", var.name, element(var.azs, count.index)))}"
}

resource "aws_subnet" "private_rds_subnets" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${var.private_rds_subnets[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.private_rds_subnets)}"
  tags              = "${map("Name", format("tf-%s-subnet-private-db-%s", var.name, element(var.azs, count.index)))}"
}

resource "aws_db_subnet_group" "private_rds_subnets" {
  name        = "tf-${var.name}-rds-subnet-group"
  description = "Database subnet groups for ${var.name}"
  subnet_ids  = ["${aws_subnet.private_rds_subnets.*.id}"]
  count       = "${length(var.private_rds_subnets) > 0 ? 1 : 0}"
}

resource "aws_subnet" "private_cache_subnets" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${var.private_cache_subnets[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  count             = "${length(var.private_cache_subnets)}"
  tags              = "${map("Name", format("tf-%s-subnet-private-cache-%s", var.name, element(var.azs, count.index)))}"
}

resource "aws_elasticache_subnet_group" "private_cache_subnets" {
  name        = "tf-${var.name}-elasticache-subnet-group"
  description = "Elasticache subnet groups for ${var.name}"
  subnet_ids  = ["${aws_subnet.private_cache_subnets.*.id}"]
  count       = "${length(var.private_cache_subnets) > 0 ? 1 : 0}"
}

resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  ingress {
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = ["${var.cidr}", "${var.peer_vpc_cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
