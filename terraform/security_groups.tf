resource "aws_security_group" "outbound" {
  name        = "tf-outbound"
  description = "Grants instances all outbound access"
  vpc_id      = "${module.vpc.vpc_id}"

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

resource "aws_security_group" "ssh" {
  name        = "tf-ssh"
  description = "Grants access to ssh"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      # Allow bastion host to SSH in https://jira.hobsons.com/browse/NAWS-443
      "${concat(var.cidr_whitelist, var.cidr_devtools)}",
    ]
  }
}

resource "aws_security_group" "web-public" {
  name        = "tf-web-public"
  description = "Allows access to common web ports from the entire Internet"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0", # Everyone
    ]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0", # Everyone
    ]
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}"]
  }
}

resource "aws_security_group" "mail-whitelist" {
  name        = "tf-mail-whitelist"
  description = "Allows access to common port 25 from tf vpc"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port       = 25
    to_port         = 25
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}"]
  }
}

resource "aws_security_group" "mailcatcher" {
  name        = "tf-mailcatcher"
  description = "Allows access to common port 25 from tf vpc"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}", "${aws_security_group.mail-whitelist.id}"]
  }
}

resource "aws_security_group" "web-whitelist" {
  name        = "tf-web-whitelist"
  description = "Allows access to common web ports from only whitelisted networks"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      # https://jira.hobsons.com/browse/NAWS-774 Allow public LogicMonitor IPs to access webapps
      # To not hit the limit of 5 SG per ALG we are adding the list of logic monitor
      # ips here instead of creating a separate SG.
      "${concat(var.cidr_whitelist, var.logicmonitor_whitelist)}",
    ]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      # https://jira.hobsons.com/browse/NAWS-774 Allow public LogicMonitor IPs to access webapps
      # To not hit the limit of 5 SG per ALG we are adding the list of logic monitor
      # ips here instead of creating a separate SG.
      "${concat(var.cidr_whitelist, var.logicmonitor_whitelist)}",
    ]
  }

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}"]
  }
}

resource "aws_security_group" "learnapi-whitelist" {
  name        = "tf-learnapi-whitelist"
  description = "Allows access to learnapi from only whitelisted networks on port 443"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_learnapi_NAT_whitelist}"]
  }
}

resource "aws_security_group" "devtools-vpc-nat-gw-whitelist" {
  name        = "tf-devtools-vpc-nat-gw-whitelist"
  description = "Allows access to common web ports from the DevTools VPC NAT gateways"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_devtools_vpc_nat_gw}"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_devtools_vpc_nat_gw}"]
  }

  # learnapi HTTP port
  ingress {
    from_port   = 6064
    to_port     = 6064
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_devtools_vpc_nat_gw}"]
  }

  # legacyapi HTTP port
  ingress {
    from_port   = 8742
    to_port     = 8742
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_devtools_vpc_nat_gw}"]
  }
}

resource "aws_security_group" "nat-gw-whitelist" {
  name        = "tf-nat-gw-whitelist"
  description = "Allows access to common web ports from NAT gateways from this account"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.cidr_devtools_vpc_nat_gw, module.vpc.nat_gateway_public_ip_cidrs)}"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.cidr_devtools_vpc_nat_gw, module.vpc.nat_gateway_public_ip_cidrs)}"]
  }

  # learnapi HTTP port
  ingress {
    from_port   = 6064
    to_port     = 6064
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.cidr_devtools_vpc_nat_gw, module.vpc.nat_gateway_public_ip_cidrs)}"]
  }

  # legacyapi HTTP port
  ingress {
    from_port   = 8742
    to_port     = 8742
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.cidr_devtools_vpc_nat_gw, module.vpc.nat_gateway_public_ip_cidrs)}"]
  }

  # iambridge HTTP port
  ingress {
    from_port   = 8757
    to_port     = 8757
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.cidr_devtools_vpc_nat_gw, module.vpc.nat_gateway_public_ip_cidrs)}"]
  }

  # edocsmtm edocsmtmrcv edocssub edocssubp edocsupload edocsoauth edocsinoauth HTTP port
  ingress {
    from_port   = 8052
    to_port     = 8052
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.cidr_devtools_vpc_nat_gw, module.vpc.nat_gateway_public_ip_cidrs)}"]
  }

  # edocs config
  ingress {
    from_port   = 8056
    to_port     = 8056
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.cidr_devtools_vpc_nat_gw, module.vpc.nat_gateway_public_ip_cidrs)}"]
  }
}

resource "aws_security_group" "icmp" {
  name        = "tf-icmp"
  description = "Allows access to ping"
  vpc_id      = "${module.vpc.vpc_id}"

  # Allow ICMP echo
  # https://github.com/hashicorp/terraform/issues/1313#issuecomment-107619807
  ingress {
    from_port = -1
    to_port   = -1
    protocol  = "icmp"
    self      = true
  }
}

resource "aws_security_group" "aurora-private" {
  name        = "tf-aurora-private"
  description = "Allows access to the database from the web application"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}"]
  }
}

resource "aws_security_group" "aurora-private-from-vpn" {
  name        = "tf-aurora-private-from-vpn"
  description = "Allows access to the database from the web application"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.datacenter-sjc-static_ip_prefix, var.datacenter-iad-static_ip_prefix)}"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = ["${var.datacenter-database_ip_prefix}"]
  }
}

resource "aws_security_group" "aurora-private-from-peer-vpc" {
  name        = "tf-aurora-private-peer-vpc"
  description = "Allows access to the database from the peer VPC"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = ["${data.aws_vpc.devtools_vpc.cidr_block}"]
  }
}

resource "aws_security_group" "elasticache-private" {
  name        = "tf-elasticache-private"
  description = "Allows access to the elasticache clusters from the web application"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port       = 11211
    to_port         = 11211
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}"]
  }
}

resource "aws_security_group" "elasticache-private-from-vpn" {
  name        = "tf-elasticache-private-vpn"
  description = "Allows access to the elasticache clusters from the VPN"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 11211
    to_port     = 11211
    protocol    = "tcp"
    cidr_blocks = ["${concat(var.datacenter-sjc-static_ip_prefix, var.datacenter-iad-static_ip_prefix)}"]
  }
}

resource "aws_security_group" "elasticache-private-from-peer-vpc" {
  name        = "tf-elasticache-private-vpc"
  description = "Allows access to the elasticache clusters from the Peer VPC"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 11211
    to_port     = 11211
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.devtools_vpc.cidr_block}"]
  }
}

resource "aws_security_group" "alert-logic-appliance" {
  name        = "tf-alert-logic-tm-appliance"
  description = "Alert Logic Threat Manager Appliances"

  # https://docs.alertlogic.com/install/cloud/amazon-web-services-threat-manager-direct-linux.htm
  vpc_id = "${module.vpc.vpc_id}"

  # Appliance claim. Docs requires it to be open to the world. But, we're going to
  #                  try to automate this process to avoid requiring it at all.
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}"]
  }

  # Agent updates
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}"]
  }

  # Agent data transport (between agent and appliance on local network)
  # Here we could use alert-logic-protected-hosts instead ?
  ingress {
    from_port       = 7777
    to_port         = 7777
    protocol        = "tcp"
    security_groups = ["${module.vpc.default_security_group_id}"]
  }
}

resource "aws_security_group" "jenkins-ssh-access" {
  name        = "tf-jenkins-ssh-access"
  description = "Grants ssh access to jenkins instances, if needed."

  vpc_id = "${module.vpc.vpc_id}"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${var.jenkins_security_groups}"]
  }
}
