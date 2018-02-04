module "connection-56" {
  source = "./modules/webapp"

  name                = "connection-56"
  codedeploy_path     = "family-connection"
  amis                = "${var.testapp-centos-7}"
  health_check_target = "/family-connection/service/index.php/healthcheck/gtg"
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

  aws-account-id                = "${var.aws-account-id}"
  aws-region                    = "${var.aws-region}"
  certificate_id                = "${var.certificate_id}"
  environments                  = ["${var.environments}"]
  vpc_id                        = "${module.vpc.vpc_id}"
  instance_types                = ["${var.app_56_instance_types}"]
  autoscaling_capacity_defaults = ["${var.app_autoscaling_capacity_defaults}"]
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  is_user_app                   = "true"
  is_web_app                    = "true"
  is_internal                   = "false"
  key_name                      = "${var.ec2_ssh_key_name}"
  assume_role_for_ssh_auth      = "${var.assume_role_for_ssh_auth}"

  zone_id      = "${data.aws_route53_zone.testapp_zone.zone_id}"
  zone_name    = "${data.aws_route53_zone.testapp_zone.name}"
  subnets      = ["${module.vpc.private_app_subnets}"]
  elb_subnets  = ["${module.vpc.subnets}"]
  subnet_count = "${length(module.vpc.subnets)}"

  use_http_listener = "true"

  hipchat_cloudwatch_sns = ["${aws_sns_topic.hipchat_cloudwatch_sns.*.arn}"]
  hipchat_codedeploy_sns = ["${aws_sns_topic.hipchat_codedeploy_sns.*.arn}"]
}
