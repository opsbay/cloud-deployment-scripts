module "al-appliance" {
  source = "./modules/utilitynode"
  name   = "al-appliance"
  amis   = "${var.alert-logic-appliance}"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
    "${aws_security_group.alert-logic-appliance.id}",
  ]

  aws-account-id  = "${var.aws-account-id}"
  aws-account-env = "${substr(var.aws-environment, 16, -1)}"
  aws-region      = "${var.aws-region}"
  vpc_id          = "${module.vpc.vpc_id}"

  instance_types                = "${var.alertlogic_instance_types}"
  autoscaling_capacity_defaults = "${var.utilitynode_autoscaling_capacity_defaults}"
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  is_web_app                    = "false"
  is_elb_app                    = "false"

  key_name                 = "${var.ec2_ssh_key_name}"
  assume_role_for_ssh_auth = "${var.assume_role_for_ssh_auth}"

  subnets      = ["${module.vpc.private_app_subnets}"]
  subnet_count = "${length(module.vpc.subnets)}"
  zone_id      = "${data.aws_route53_zone.testapp_zone.zone_id}"
  zone_name    = "${data.aws_route53_zone.testapp_zone.name}"
}