module "crm-56" {
  source = "./modules/webapp"

  name                = "crm-56"
  codedeploy_path     = "crm"
  health_check_target = "/signin.php"
  health_check_type   = "ELB"
  amis                = "${var.testapp-centos-7}"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
  ]

  lb_security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.web-whitelist.id}",
    "${aws_security_group.nat-gw-whitelist.id}",
  ]

  aws-account-id                = "${var.aws-account-id}"
  aws-region                    = "${var.aws-region}"
  vpc_id                        = "${module.vpc.vpc_id}"
  environments                  = ["${var.environments}"]
  instance_types                = ["${var.app_internal_instance_types}"]
  autoscaling_capacity_defaults = ["${var.app_internal_autoscaling_capacity_defaults}"]
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  is_user_app                   = "true"
  is_web_app                    = "true"
  is_internal                   = "false"
  certificate_id                = "${var.certificate_id}"
  key_name                      = "${var.ec2_ssh_key_name}"
  assume_role_for_ssh_auth      = "${var.assume_role_for_ssh_auth}"

  subnets      = ["${module.vpc.private_app_subnets}"]
  elb_subnets  = ["${module.vpc.subnets}"]
  zone_id      = "${data.aws_route53_zone.testapp_zone.zone_id}"
  zone_name    = "${data.aws_route53_zone.testapp_zone.name}"
  subnet_count = "${length(module.vpc.subnets)}"

  use_http_listener = "true"

  hipchat_cloudwatch_sns = ["${aws_sns_topic.hipchat_cloudwatch_sns.*.arn}"]
  hipchat_codedeploy_sns = ["${aws_sns_topic.hipchat_codedeploy_sns.*.arn}"]
}
