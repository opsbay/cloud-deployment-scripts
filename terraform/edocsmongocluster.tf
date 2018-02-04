module "edocsmongocluster" {
  source = "./modules/mongo-cluster"

  name = "edocs"
  amis = "${var.testapp-centos-7}"

  mongo_data_size = 1000

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
  ]

  aws-account-id  = "${var.aws-account-id}"
  aws-region      = "${var.aws-region}"
  aws-environment = "${var.aws-environment}"
  environments    = ["${var.environments}"]
  vpc_id          = "${module.vpc.vpc_id}"
  instance_types  = ["${var.service_instance_types}"]

  private_app_subnets     = ["${module.vpc.private_app_subnets}"]
  private_app_subnets_azs = ["${module.vpc.private_app_subnets_azs}"]

  key_name = "${var.ec2_ssh_key_name}"
}

resource "aws_security_group_rule" "edocsmongocluster_dc_replication" {
  type        = "ingress"
  from_port   = 27017
  to_port     = 27017
  protocol    = "tcp"
  cidr_blocks = ["${var.edocsmongo_whitelist[var.environments[count.index]]}"]

  security_group_id = "${element(module.edocsmongocluster.security_group_ids, count.index)}"

  count = "${length(var.environments)}"
}
