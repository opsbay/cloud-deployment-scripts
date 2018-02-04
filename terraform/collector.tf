module "lm-collector" {
  source = "./modules/utilitynode"
  name   = "lm-collector"
  amis   = "${var.testapp-centos-7}"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
  ]

  aws-account-id  = "${var.aws-account-id}"
  aws-account-env = "${substr(var.aws-environment, 16, -1)}"
  aws-region      = "${var.aws-region}"
  vpc_id          = "${module.vpc.vpc_id}"

  instance_types                = "${var.lm_collector_instance_types}"
  autoscaling_capacity_defaults = "${var.utilitynode_autoscaling_capacity_defaults}"
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  is_web_app                    = "false"

  key_name                 = "${var.ec2_ssh_key_name}"
  assume_role_for_ssh_auth = "${var.assume_role_for_ssh_auth}"

  subnets      = ["${module.vpc.private_app_subnets}"]
  subnet_count = "${length(module.vpc.subnets)}"
  zone_id      = "${data.aws_route53_zone.testapp_zone.zone_id}"
  zone_name    = "${data.aws_route53_zone.testapp_zone.name}"

  # Cloud-init script passed to the launch configuration
  user_data = "${file("../cloud-init-scripts/collector_init.sh")}"
}
