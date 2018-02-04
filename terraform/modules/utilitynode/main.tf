resource "aws_iam_role_policy" "utilitynode_auth_policy" {
  depends_on = ["aws_iam_role.utilitynode_role"]

  name = "tf-${var.name}_${var.aws-account-env}-auth_policy"
  role = "tf-${var.name}-${var.aws-account-env}-cd_role"

  # See the if-else statement section of this article
  # https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
  policy = "${element(concat(data.aws_iam_policy_document.iam_user_auth.*.json,data.aws_iam_policy_document.assume_auth_role.*.json), 0)}"
}

resource "aws_iam_role_policy" "utilitynode_policy" {
  depends_on = ["aws_iam_role.utilitynode_role"]

  name = "tf-${var.name}_${var.aws-account-env}_cd_policy"
  role = "tf-${var.name}-${var.aws-account-env}-cd_role"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "autoscaling:Describe*",
            "autoscaling:EnterStandby",
            "autoscaling:ExitStandby",
            "autoscaling:UpdateAutoScalingGroup",
            "autoscaling:CompleteLifecycleAction",
            "autoscaling:DeleteLifecycleHook",
            "autoscaling:PutLifecycleHook",
            "autoscaling:RecordLifecycleActionHeartbeat",
            "ec2:Describe*",
            "tag:getTagKeys",
            "tag:getTagValues",
            "tag:GetResources"
        ],
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:ListAllMyBuckets",
            "s3:GetBucketLocation"
        ],
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:Get*"
      ],
      "Resource": [
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/logicmonitor/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/newrelic/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/efs/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/splunk/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/nessus/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/${var.name}/*",
        "arn:aws:s3:::unmanaged-codedeploy-${var.aws-account-id}/placeholder/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "additional_role_policy" {
  name   = "tf-${var.name}_${var.aws-account-env}_additional_policy_${count.index}"
  role   = "${element(aws_iam_role.utilitynode_role.*.name, count.index)}"
  policy = "${element(var.additional_role_policies, count.index)}"
  count  = "${var.additional_role_policy_count}"
}

resource "aws_iam_role" "utilitynode_role" {
  name = "tf-${var.name}-${var.aws-account-env}-cd_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_elb" "utilitynode-int-elb" {
  name            = "tf-${var.name}-${var.aws-account-env}-int-elb"
  internal        = true
  security_groups = ["${var.elb_security_groups}"]
  subnets         = ["${var.elb_subnets}"]

  listener {
    instance_port     = "${var.int_elb_instance_port}"
    instance_protocol = "${var.int_elb_instance_protocol}"
    lb_port           = "${var.int_lb_port}"
    lb_protocol       = "${var.int_lb_protocol}"
  }

  count = "${var.is_elb_app ? 1 : 0}"
}

resource "aws_alb" "utilitynode-alb" {
  name = "tf-${var.name}-${var.aws-account-env}-alb"

  security_groups = ["${var.lb_security_groups}"]
  subnets         = ["${var.alb_subnets}"]

  count = "${var.is_web_app ? 1 : 0}"

  tags {
    "associate_with_waf" = "true"
  }
}

resource "aws_alb_target_group" "utilitynode-alb-target-group" {
  name                 = "tf-${var.name}-${var.aws-account-env}-grp"
  port                 = "${var.instance_port}"
  protocol             = "${var.instance_protocol}"
  vpc_id               = "${var.vpc_id}"
  deregistration_delay = 30

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    port                = "${var.health_check_port}"
    path                = "${var.health_check_target}"
    interval            = 30
  }

  count = "${var.is_web_app ? 1 : 0}"
}

resource "aws_alb_listener" "utilitynode-web-ssl" {
  depends_on = ["aws_alb_target_group.utilitynode-alb-target-group"]

  load_balancer_arn = "${element(aws_alb.utilitynode-alb.*.arn, count.index)}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.certificate_id}"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.utilitynode-alb-target-group.*.arn, count.index)}"
    type             = "forward"
  }

  count = "${var.is_web_app ? 1 : 0}"
}

resource "aws_alb_listener" "utilitynode-web" {
  depends_on = ["aws_alb_target_group.utilitynode-alb-target-group"]

  load_balancer_arn = "${element(aws_alb.utilitynode-alb.*.arn, count.index)}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.utilitynode-alb-target-group.*.arn, count.index)}"
    type             = "forward"
  }

  count = "${var.is_web_app ? 1 : 0}"
}

resource "aws_iam_instance_profile" "utilitynode-instances" {
  depends_on = ["aws_iam_role.utilitynode_role"]

  name = "tf-${var.name}-${var.aws-account-env}-utilitynode-instances"
  role = "tf-${var.name}-${var.aws-account-env}-cd_role"
}

resource "aws_launch_configuration" "utilitynode-lc" {
  name_prefix   = "tf-${var.name}-${var.aws-account-env}-lc"
  image_id      = "${lookup(var.amis, var.aws-region)}"
  instance_type = "${lookup(var.instance_types, var.aws-account-env)}"

  security_groups = ["${var.security_groups}"]

  iam_instance_profile = "tf-${var.name}-${var.aws-account-env}-utilitynode-instances"

  key_name = "${var.key_name}"

  user_data = "${var.user_data}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    delete_on_termination = true
  }

  count = "${!var.add_additional_block_device ? 1 : 0}"
}

resource "aws_launch_configuration" "utilitynode-abd-lc" {
  name_prefix   = "tf-${var.name}-${var.aws-account-env}-lc"
  image_id      = "${lookup(var.amis, var.aws-region)}"
  instance_type = "${lookup(var.instance_types, var.aws-account-env)}"

  security_groups = ["${var.security_groups}"]

  iam_instance_profile = "tf-${var.name}-${var.aws-account-env}-utilitynode-instances"

  key_name = "${var.key_name}"

  user_data = "${var.user_data}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    delete_on_termination = true
  }

  ebs_block_device {
    device_name = "/dev/sdb"
    volume_size = "${var.additional_block_device_size}"
    encrypted   = "${var.encrypt_additional_block_device}"
  }

  count = "${var.add_additional_block_device ? 1 : 0}"
}

resource "aws_autoscaling_group" "utilitynode-asg" {
  name = "tf-${var.name}-${var.aws-account-env}-asg"

  # The capacities are read from an auto-generated file if the corresponding
  # AutoScaling Group does not exist or could not be polled, terraform will then
  # lookup the variable from the defaults defined in variables.tf, if for some reason
  # it can't find that variable, it defaults to 1.

  min_size                  = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-min", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env}_min_size", 1))}"
  max_size                  = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-max", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env}_max_size", 1))}"
  desired_capacity          = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-desired", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env }_min_size", 1))}"
  wait_for_capacity_timeout = 0
  # TODO: Set final name of launch configuration
  launch_configuration = "${var.add_additional_block_device ? element(concat(aws_launch_configuration.utilitynode-abd-lc.*.name, list("")), count.index) : element(concat(aws_launch_configuration.utilitynode-lc.*.name, list("")), count.index)}"
  health_check_type    = "${var.health_check_type}"
  vpc_zone_identifier  = ["${var.subnets}"]
  enabled_metrics      = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  load_balancers       = []
  termination_policies = [
    "OldestLaunchConfiguration",
    "OldestInstance",
    "Default",
  ]
  lifecycle {
    ignore_changes = ["desired_capacity", "max_size", "min_size"]
  }
  tag {
    key                 = "Name"
    value               = "tf-${var.name}-${var.aws-account-env}-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = "${var.aws-account-env}"
    propagate_at_launch = true
  }
  tag {
    key                 = "FullName"
    value               = "tf-${var.name}-${var.aws-account-env}-instance"
    propagate_at_launch = true
  }
  count = "${!var.is_web_app && !var.is_elb_app ? 1 : 0}"
}

resource "aws_autoscaling_group" "utilitynode-elb-asg" {
  name = "tf-${var.name}-${var.aws-account-env}-asg"

  depends_on = [
    "aws_elb.utilitynode-int-elb",
  ]

  # The capacities are read from an auto-generated file if the corresponding
  # AutoScaling Group does not exist or could not be polled, terraform will then
  # lookup the variable from the defaults defined in variables.tf, if for some reason
  # it can't find that variable, it defaults to 1.

  min_size                  = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-min", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env}_min_size", 1))}"
  max_size                  = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-max", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env}_max_size", 1))}"
  desired_capacity          = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-desired", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env }_min_size", 1))}"
  wait_for_capacity_timeout = 0
  # TODO: Set final name of launch configuration
  launch_configuration = "${var.add_additional_block_device ? element(concat(aws_launch_configuration.utilitynode-abd-lc.*.name, list("")), count.index) : element(concat(aws_launch_configuration.utilitynode-lc.*.name, list("")), count.index)}"
  health_check_type    = "${var.health_check_type}"
  vpc_zone_identifier  = ["${var.subnets}"]
  enabled_metrics      = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  load_balancers       = ["tf-${var.name}-${var.aws-account-env}-int-elb"]
  termination_policies = [
    "OldestLaunchConfiguration",
    "OldestInstance",
    "Default",
  ]
  lifecycle {
    ignore_changes = ["desired_capacity", "max_size", "min_size"]
  }
  tag {
    key                 = "Name"
    value               = "tf-${var.name}-${var.aws-account-env}-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = "${var.aws-account-env}"
    propagate_at_launch = true
  }
  tag {
    key                 = "FullName"
    value               = "tf-${var.name}-${var.aws-account-env}-instance"
    propagate_at_launch = true
  }
  count = "${!var.is_web_app && var.is_elb_app ? 1 : 0}"
}

resource "aws_autoscaling_group" "utilitynode-elb-alb-asg" {
  name = "tf-${var.name}-${var.aws-account-env}-asg"

  depends_on = [
    "aws_elb.utilitynode-int-elb",
    "aws_alb.utilitynode-alb",
  ]

  # The capacities are read from an auto-generated file if the corresponding
  # AutoScaling Group does not exist or could not be polled, terraform will then
  # lookup the variable from the defaults defined in variables.tf, if for some reason
  # it can't find that variable, it defaults to 1.

  min_size                  = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-min", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env}_min_size", 1))}"
  max_size                  = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-max", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env}_max_size", 1))}"
  desired_capacity          = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-desired", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env }_min_size", 1))}"
  wait_for_capacity_timeout = 0
  # TODO: Set final name of launch configuration
  launch_configuration = "${var.add_additional_block_device ? element(concat(aws_launch_configuration.utilitynode-abd-lc.*.name, list("")), count.index) : element(concat(aws_launch_configuration.utilitynode-lc.*.name, list("")), count.index)}"
  health_check_type    = "${var.health_check_type}"
  vpc_zone_identifier  = ["${var.subnets}"]
  enabled_metrics      = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  load_balancers       = ["tf-${var.name}-${var.aws-account-env}-int-elb"]
  target_group_arns = [
    "${element(aws_alb_target_group.utilitynode-alb-target-group.*.arn, count.index)}",
  ]
  termination_policies = [
    "OldestLaunchConfiguration",
    "OldestInstance",
    "Default",
  ]
  lifecycle {
    ignore_changes = ["desired_capacity", "max_size", "min_size"]
  }
  tag {
    key                 = "Name"
    value               = "tf-${var.name}-${var.aws-account-env}-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = "${var.aws-account-env}"
    propagate_at_launch = true
  }
  tag {
    key                 = "FullName"
    value               = "tf-${var.name}-${var.aws-account-env}-instance"
    propagate_at_launch = true
  }
  count = "${var.is_web_app && var.is_elb_app ? 1 : 0}"
}

resource "aws_autoscaling_group" "utilitynode-web-asg" {
  depends_on = [
    "aws_alb.utilitynode-alb",
  ]

  name = "tf-${var.name}-${var.aws-account-env}-asg"

  # The capacities are read from an auto-generated file if the corresponding
  # AutoScaling Group does not exist or could not be polled, terraform will then
  # lookup the variable from the defaults defined in variables.tf, if for some reason
  # it can't find that variable, it defaults to 1.

  min_size                  = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-min", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env}_min_size", 1))}"
  max_size                  = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-max", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env}_max_size", 1))}"
  desired_capacity          = "${lookup(var.autoscaling_capacity,  "tf-${var.name}-${var.aws-account-env}-asg-desired", lookup(var.autoscaling_capacity_defaults, "${var.aws-account-env }_min_size", 1))}"
  wait_for_capacity_timeout = 0
  # TODO: Set final name of launch configuration
  launch_configuration = "${var.add_additional_block_device ? element(concat(aws_launch_configuration.utilitynode-abd-lc.*.name, list("")), count.index) : element(concat(aws_launch_configuration.utilitynode-lc.*.name, list("")), count.index)}"
  health_check_type    = "${var.health_check_type}"
  vpc_zone_identifier  = ["${var.subnets}"]
  enabled_metrics      = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  load_balancers       = []
  target_group_arns = [
    "${element(aws_alb_target_group.utilitynode-alb-target-group.*.arn, count.index)}",
  ]
  termination_policies = [
    "OldestLaunchConfiguration",
    "OldestInstance",
    "Default",
  ]
  lifecycle {
    ignore_changes = ["desired_capacity", "max_size", "min_size"]
  }
  tag {
    key                 = "Name"
    value               = "tf-${var.name}-${var.aws-account-env}-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = "${var.aws-account-env}"
    propagate_at_launch = true
  }
  tag {
    key                 = "FullName"
    value               = "tf-${var.name}-${var.aws-account-env}-instance"
    propagate_at_launch = true
  }
  count = "${var.is_web_app && !var.is_elb_app ? 1 : 0}"
}

resource "aws_route53_record" "utilitynode-domain" {
  depends_on = [
    "aws_alb.utilitynode-alb",
  ]

  zone_id = "${var.zone_id}"
  name    = "tf-${var.name}-${var.aws-account-env}.${var.zone_name}"
  type    = "CNAME"
  ttl     = "300"

  records = [
    "${element(aws_alb.utilitynode-alb.*.dns_name, count.index)}",
  ]

  count = "${var.is_web_app ? 1 : 0}"
}

resource "aws_route53_record" "utilitynode-internal-domain" {
  depends_on = [
    "aws_elb.utilitynode-int-elb",
  ]

  zone_id = "${var.zone_id}"
  name    = "tf-int-${var.name}-${var.aws-account-env}.${var.zone_name}"
  type    = "CNAME"
  ttl     = "300"

  records = [
    "${element(aws_elb.utilitynode-int-elb.*.dns_name, count.index)}",
  ]

  count = "${var.is_elb_app ? 1 : 0}"
}

data "aws_iam_policy_document" "assume_auth_role" {
  # See the if-else statement section of this article
  # https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
  count = "${var.assume_role_for_ssh_auth}"

  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::253369875794:role/unmanaged-IAM-user-SSH-reader"]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/ssh-auth/*"]
  }
}

data "aws_iam_policy_document" "iam_user_auth" {
  # See the if-else statement section of this article
  # https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
  count = "${1 - var.assume_role_for_ssh_auth}"

  statement {
    actions = [
      "iam:ListUsers",
      "iam:GetGroup",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "iam:ListSSHPublicKeys",
      "iam:GetSSHPublicKey",
    ]

    resources = ["arn:aws:iam::${var.aws-account-id}:user/*"]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/ssh-auth/*"]
  }
}

#### ASG HOOKS ################################################################

resource "aws_iam_role" "utilitynode-asg-hook-role" {
  name = "tf-${var.name}-${var.aws-account-env}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  count = "${var.use_asg_hook_on_launch ? 1 : 0}"
}

resource "aws_iam_role_policy" "utilitynode-asg-hook-policy" {
  name = "tf-${var.name}-${var.aws-account-env}-publish-role-policy"
  role = "tf-${var.name}-${var.aws-account-env}-role"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [ {
      "Effect": "Allow",
      "Resource": "${var.notification_target_arn}",
      "Action": [
        "sns:Publish"
      ]
  } ]
}
EOF

  count = "${var.use_asg_hook_on_launch ? 1 : 0}"
}

resource "aws_autoscaling_lifecycle_hook" "tf-asg-launching-hook" {
  # https://www.terraform.io/docs/providers/aws/r/autoscaling_lifecycle_hooks.html
  depends_on = [
    "aws_iam_role.utilitynode-asg-hook-role",
    "aws_autoscaling_group.utilitynode-asg",
  ]

  name                    = "tf-asg-${var.name}-${var.aws-account-env}-hook"
  role_arn                = "${aws_iam_role.utilitynode-asg-hook-role.arn}"
  default_result          = "CONTINUE"
  heartbeat_timeout       = 2000
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  notification_metadata   = "${var.notification_metadata}"
  notification_target_arn = "${var.notification_target_arn}"

  autoscaling_group_name = "tf-${var.name}-${var.aws-account-env}-asg"
  count                  = "${var.use_asg_hook_on_launch && !var.is_web_app && !var.is_elb_app ? 1 : 0}"
}

resource "aws_autoscaling_lifecycle_hook" "tf-elb-asg-launching-hook" {
  # https://www.terraform.io/docs/providers/aws/r/autoscaling_lifecycle_hooks.html
  depends_on = [
    "aws_iam_role.utilitynode-asg-hook-role",
    "aws_autoscaling_group.utilitynode-elb-asg",
  ]

  name                    = "tf-asg-${var.name}-${var.aws-account-env}-hook"
  role_arn                = "${aws_iam_role.utilitynode-asg-hook-role.arn}"
  default_result          = "CONTINUE"
  heartbeat_timeout       = 2000
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  notification_metadata   = "${var.notification_metadata}"
  notification_target_arn = "${var.notification_target_arn}"

  autoscaling_group_name = "tf-${var.name}-${var.aws-account-env}-asg"
  count                  = "${var.use_asg_hook_on_launch && !var.is_web_app && var.is_elb_app ? 1 : 0}"
}

resource "aws_autoscaling_lifecycle_hook" "tf-elb-alb-asg-launching-hook" {
  # https://www.terraform.io/docs/providers/aws/r/autoscaling_lifecycle_hooks.html
  depends_on = [
    "aws_iam_role.utilitynode-asg-hook-role",
    "aws_autoscaling_group.utilitynode-elb-alb-asg",
  ]

  name                    = "tf-asg-${var.name}-${var.aws-account-env}-hook"
  role_arn                = "${aws_iam_role.utilitynode-asg-hook-role.arn}"
  default_result          = "CONTINUE"
  heartbeat_timeout       = 2000
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  notification_metadata   = "${var.notification_metadata}"
  notification_target_arn = "${var.notification_target_arn}"

  autoscaling_group_name = "tf-${var.name}-${var.aws-account-env}-asg"
  count                  = "${var.use_asg_hook_on_launch && var.is_web_app && var.is_elb_app ? 1 : 0}"
}

resource "aws_autoscaling_lifecycle_hook" "tf-alb-asg-launching-hook" {
  # https://www.terraform.io/docs/providers/aws/r/autoscaling_lifecycle_hooks.html
  depends_on = [
    "aws_iam_role.utilitynode-asg-hook-role",
    "aws_autoscaling_group.utilitynode-web-asg",
  ]

  name                    = "tf-asg-${var.name}-${var.aws-account-env}-hook"
  role_arn                = "${aws_iam_role.utilitynode-asg-hook-role.arn}"
  default_result          = "CONTINUE"
  heartbeat_timeout       = 2000
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  notification_metadata   = "${var.notification_metadata}"
  notification_target_arn = "${var.notification_target_arn}"

  autoscaling_group_name = "tf-${var.name}-${var.aws-account-env}-asg"
  count                  = "${var.use_asg_hook_on_launch && var.is_web_app && var.is_elb_app ? 1 : 0}"
}
