module "mailcatcher" {
  source     = "./modules/utilitynode"
  name       = "mailcatcher"
  amis       = "${var.testapp-centos-7}"
  is_web_app = "true"
  is_elb_app = "true"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
    "${aws_security_group.mailcatcher.id}",
  ]

  lb_security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.web-whitelist.id}",
    "${aws_security_group.nat-gw-whitelist.id}",
  ]

  elb_security_groups = [
    "${aws_security_group.mail-whitelist.id}",
    "${module.vpc.default_security_group_id}",
  ]

  # It should be ELB once it's working and stable
  health_check_type   = "EC2"
  health_check_target = "/"

  aws-account-id  = "${var.aws-account-id}"
  aws-account-env = "${substr(var.aws-environment, 16, -1)}"
  aws-region      = "${var.aws-region}"
  vpc_id          = "${module.vpc.vpc_id}"

  instance_types                = "${var.mailcatcher_instance_types}"
  autoscaling_capacity_defaults = "${var.utilitynode_autoscaling_capacity_defaults}"
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  certificate_id                = "${lookup(var.certificate_id, "mailcatcher", var.certificate_id["star"])}"

  key_name                 = "${var.ec2_ssh_key_name}"
  assume_role_for_ssh_auth = "${var.assume_role_for_ssh_auth}"

  alb_subnets  = ["${module.vpc.subnets}"]
  elb_subnets  = ["${module.vpc.private_app_subnets}"]
  subnets      = ["${module.vpc.private_app_subnets}"]
  subnet_count = "${length(module.vpc.subnets)}"
  zone_id      = "${data.aws_route53_zone.testapp_zone.zone_id}"
  zone_name    = "${data.aws_route53_zone.testapp_zone.name}"

  int_elb_instance_port     = 25
  int_elb_instance_protocol = "tcp"
  int_lb_port               = 25
  int_lb_protocol           = "tcp"

  # Cloud-init script passed to the launch configuration
  user_data = "${file("../cloud-init-scripts/mailcatcher.conf")}"
}
