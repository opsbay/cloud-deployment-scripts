module "iambridge" {
  source = "./modules/webapp"

  name                = "iambridge"
  codedeploy_path     = "iambridge"
  health_check_port   = 8757
  health_check_target = "/management/health"
  health_check_type   = "ELB"
  amis                = "${var.testapp-centos-7}"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
  ]

  lb_security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.web-public.id}",
    "${aws_security_group.iambridge-service.id}",
    "${aws_security_group.nat-gw-whitelist.id}",
  ]

  instance_port = 8756

  aws-account-id                = "${var.aws-account-id}"
  aws-region                    = "${var.aws-region}"
  environments                  = ["${var.environments}"]
  vpc_id                        = "${module.vpc.vpc_id}"
  instance_types                = ["${var.service_instance_types}"]
  autoscaling_capacity_defaults = ["${var.service_autoscaling_capacity_defaults}"]
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  is_user_app                   = "false"
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

  use_http_listener = "false"

  hipchat_cloudwatch_sns = ["${aws_sns_topic.hipchat_cloudwatch_sns.*.arn}"]
  hipchat_codedeploy_sns = ["${aws_sns_topic.hipchat_codedeploy_sns.*.arn}"]
}

resource "aws_security_group" "iambridge-service" {
  name        = "tf-iam-bridge-service-sg"
  description = "Allows access to legacy API service and healthcheck"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 8756
    to_port   = 8756
    protocol  = "tcp"

    security_groups = [
      "${module.vpc.default_security_group_id}",
    ]
  }

  ingress {
    from_port = 8757
    to_port   = 8757
    protocol  = "tcp"

    security_groups = [
      "${module.vpc.default_security_group_id}",
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}
