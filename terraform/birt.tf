module "birt" {
  source = "./modules/webapp"

  name                = "birt"
  codedeploy_path     = "naviance-birt"
  health_check_port   = 8080
  health_check_target = "/whatsup/index.html"
  health_check_type   = "ELB"
  amis                = "${var.testapp-centos-7}"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
  ]

  lb_security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.nat-gw-whitelist.id}",
    "${aws_security_group.birt-whitelist.id}",
  ]

  instance_port = 8080

  aws-account-id                = "${var.aws-account-id}"
  aws-region                    = "${var.aws-region}"
  environments                  = ["${var.environments}"]
  vpc_id                        = "${module.vpc.vpc_id}"
  instance_types                = ["${var.service_instance_types}"]
  autoscaling_capacity_defaults = ["${var.service_autoscaling_capacity_defaults}"]
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  is_user_app                   = "false"
  is_web_app                    = "true"
  is_internal                   = "true"
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

resource "aws_security_group" "birt-whitelist" {
  name        = "tf-birt-sg"
  description = "Allows access to BIRT API"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    security_groups = [
      "${module.vpc.default_security_group_id}",
    ]
  }

  ingress {
    from_port = 443
    to_port   = 443
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
