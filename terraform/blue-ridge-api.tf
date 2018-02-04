module "blue-ridge-api" {
  source = "./modules/webapp"

  name                = "blue-ridge-api"
  codedeploy_path     = "naviance-blue-ridge-api"
  amis                = "${var.testapp-centos-7}"
  health_check_target = "/health-check"
  health_check_type   = "ELB"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
  ]

  lb_security_groups = [
    "${module.vpc.default_security_group_id}",
    "${var.aws-environment == "hobsons-navianceprod" ? aws_security_group.web-public.id : aws_security_group.web-whitelist.id}",
    "${aws_security_group.nat-gw-whitelist.id}",
  ]

  aws-account-id           = "${var.aws-account-id}"
  aws-region               = "${var.aws-region}"
  certificate_id           = "${var.certificate_id}"
  environments             = ["${var.environments}"]
  vpc_id                   = "${module.vpc.vpc_id}"
  instance_types           = ["${var.service_instance_types}"]
  assume_role_for_ssh_auth = "${var.assume_role_for_ssh_auth}"

  autoscaling_capacity_defaults = ["${var.service_autoscaling_capacity_defaults}"]
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  is_user_app                   = "true"
  is_web_app                    = "true"
  is_internal                   = "false"

  key_name = "${var.ec2_ssh_key_name}"

  zone_id      = "${data.aws_route53_zone.testapp_zone.zone_id}"
  zone_name    = "${data.aws_route53_zone.testapp_zone.name}"
  subnets      = ["${module.vpc.private_app_subnets}"]
  elb_subnets  = ["${module.vpc.subnets}"]
  subnet_count = "${length(module.vpc.subnets)}"

  use_http_listener = "true"

  hipchat_cloudwatch_sns = ["${aws_sns_topic.hipchat_cloudwatch_sns.*.arn}"]
  hipchat_codedeploy_sns = ["${aws_sns_topic.hipchat_codedeploy_sns.*.arn}"]
}
