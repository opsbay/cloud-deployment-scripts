resource "aws_iam_role_policy" "auth_policy" {
  name = "tf-${var.name}_${var.environments[count.index]}-auth_policy"
  role = "${element(aws_iam_role.xferapp_role_v2.*.id, count.index)}"

  # See the if-else statement section of this article
  # https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
  policy = "${element(concat(data.aws_iam_policy_document.iam_user_auth.*.json,data.aws_iam_policy_document.assume_auth_role.*.json), 0)}"

  count = "${length(var.environments)}"
}

resource "aws_iam_role_policy" "xferapp_policy" {
  name = "tf-${var.name}_${var.environments[count.index]}_cd_policy"
  role = "${element(aws_iam_role.xferapp_role_v2.*.name, count.index)}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:Batch*",
        "codedeploy:Get*",
        "codedeploy:List*",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "autoscaling:Describe*",
        "autoscaling:EnterStandby",
        "autoscaling:ExitStandby",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLifecycleHooks",
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:DeleteLifecycleHook",
        "autoscaling:PutLifecycleHook",
        "autoscaling:RecordLifecycleActionHeartbeat",
        "ec2:Describe*",
        "tag:getTagKeys",
        "tag:getTagValues",
        "tag:GetResources",
        "sns:Publish"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:${var.aws-region}:${var.aws-account-id}:parameter/codedeploy-efs"
      ]
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
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/${var.environments[count.index]}/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/aurora-cluster/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/newrelic/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/elasticache/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/efs/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/splunk/*",
        "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/nessus/*",
        "arn:aws:s3:::unmanaged-codedeploy-${var.aws-account-id}/placeholder/*",
        "arn:aws:s3:::unmanaged-codedeploy-${var.aws-account-id}/nodejs/*",
        "arn:aws:s3:::unmanaged-codedeploy-${var.aws-account-id}/${var.codedeploy_path}/*",
        "arn:aws:s3:::unmanaged-codedeploy-253369875794/${var.codedeploy_path}/*",
        "arn:aws:s3:::aws-codedeploy-${var.aws-region}/*"
      ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:ListBucket",
            "s3:GetBucketLocation",
            "s3:ListBucketMultipartUploads",
            "s3:GetObject",
            "s3:GetObjectAcl",
            "s3:GetObjectVersion",
            "s3:GetObjectVersionAcl",
            "s3:PutObject",
            "s3:DeleteObject"
        ],
        "Resource": [
            "arn:aws:s3:::unmanaged-clientfiles-*",
            "arn:aws:s3:::unmanaged-edocs-*",
            "arn:aws:s3:::unmanaged-keyfacts-*",
            "arn:aws:s3:::unmanaged-clientfiles-*/*",
            "arn:aws:s3:::unmanaged-edocs-*/*",
            "arn:aws:s3:::unmanaged-keyfacts-*/*"
        ],
        "Condition": {}
    }
  ]
}
EOF

  count = "${length(var.environments)}"
}

resource "aws_iam_role_policy" "additional_role_policy" {
  name   = "tf-${var.name}_${var.environments[count.index % length(var.environments)]}_additional_policy_${(count.index / length(var.environments))}"
  role   = "${element(aws_iam_role.xferapp_role_v2.*.name, (count.index % length(var.environments)))}"
  policy = "${element(var.additional_role_policies, count.index)}"
  count  = "${length(var.environments) * var.additional_role_policy_count}"
}

resource "aws_iam_role" "xferapp_role_v2" {
  name = "tf-${var.name}-${var.environments[count.index]}-cd_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "codedeploy.amazonaws.com",
          "ec2.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  count = "${length(var.environments)}"
}

resource "aws_iam_instance_profile" "xferapp-codedeploy-instances" {
  name  = "tf-${var.name}-${var.environments[count.index]}-codedeploy-instances"
  role  = "${element(aws_iam_role.xferapp_role_v2.*.name, count.index)}"
  count = "${length(var.environments)}"
}

resource "aws_codedeploy_app" "xferapp" {
  name = "tf-${var.name}"
}

# See cloudformation/waf/README.md
# for information on adding WAF rules.

resource "aws_alb" "alb" {
  name = "tf-${var.name}-${var.environments[count.index]}-alb"

  security_groups = ["${var.lb_security_groups}"]
  subnets         = ["${var.elb_subnets}"]

  count = "${var.is_web_app ? length(var.environments) : 0}"

  internal = "${var.is_internal}"

  tags {
    "associate_with_waf" = "true"
  }
}

resource "aws_alb_target_group" "alb-target-group" {
  name                 = "tf-${var.name}-${var.environments[count.index]}-grp"
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

  count = "${var.is_web_app ? length(var.environments) : 0}"
}

resource "aws_alb_listener" "web-ssl" {
  depends_on = ["aws_alb_target_group.alb-target-group"]

  load_balancer_arn = "${element(aws_alb.alb.*.arn, count.index)}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${lookup(var.certificate_id, format("%s-%s", var.name, var.environments[count.index]), var.certificate_id["star"])}"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.alb-target-group.*.arn, count.index)}"
    type             = "forward"
  }

  count = "${var.is_web_app ? length(var.environments) : 0}"
}

resource "aws_alb_listener" "web" {
  depends_on = ["aws_alb_target_group.alb-target-group"]

  load_balancer_arn = "${element(aws_alb.alb.*.arn, count.index)}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.alb-target-group.*.arn, count.index)}"
    type             = "forward"
  }

  count = "${var.is_web_app && var.use_http_listener ? length(var.environments) : 0}"
}

resource "aws_launch_configuration" "xferapp-lc" {
  name_prefix   = "tf-${var.name}-${var.environments[count.index]}-lc-"
  image_id      = "${lookup(var.amis, var.aws-region)}"
  instance_type = "${lookup(var.instance_types, var.environments[count.index])}"

  security_groups = ["${var.security_groups}"]

  iam_instance_profile = "${element(aws_iam_instance_profile.xferapp-codedeploy-instances.*.name, count.index)}"

  key_name = "${var.key_name}"

  user_data = "${var.user_data}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    delete_on_termination = true
    volume_size           = "${var.root_block_device_size}"
  }

  count = "${length(var.environments)}"
}

resource "aws_autoscaling_group" "batch-asg" {
  name = "tf-${var.name}-${var.environments[count.index]}-asg"

  # The capacities are read from an auto-generated file if the corresponding
  # AutoScaling Group does not exist or could not be polled, terraform will then
  # lookup the variable from the defaults defined in variables.tf, if for some reason
  # it can't find that variable, it defaults to 1.
  min_size = "${lookup(var.autoscaling_capacity, "tf-${var.name}-${var.environments[count.index]}-asg-min", lookup(var.autoscaling_capacity_defaults, "${var.environments[count.index]}_min_size", 1))}"

  max_size                  = "${lookup(var.autoscaling_capacity, "tf-${var.name}-${var.environments[count.index]}-asg-max", lookup(var.autoscaling_capacity_defaults, "${var.environments[count.index]}_max_size", 1))}"
  desired_capacity          = "${lookup(var.autoscaling_capacity, "tf-${var.name}-${var.environments[count.index]}-asg-desired", lookup(var.autoscaling_capacity_defaults, "${var.environments[count.index]}_min_size", 1))}"
  wait_for_capacity_timeout = 0
  launch_configuration      = "${element(aws_launch_configuration.xferapp-lc.*.name, count.index)}"
  health_check_type         = "${var.health_check_type}"
  vpc_zone_identifier       = ["${var.subnets}"]
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  load_balancers            = []

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
    value               = "tf-${var.name}-${var.environments[count.index]}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = "${var.environments[count.index]}"
    propagate_at_launch = true
  }

  count = "${var.is_web_app ? 0 : length(var.environments)}"
}

resource "aws_autoscaling_group" "dynamic-asg" {
  depends_on = [
    "aws_alb.alb",
  ]

  name = "tf-${var.name}-${var.environments[count.index]}-asg"

  # The capacities are read from an auto-generated file if the corresponding
  # AutoScaling Group does not exist or could not be polled, terraform will then
  # lookup the variable from the defaults defined in variables.tf, if for some reason
  # it can't find that variable, it defaults to 1.
  min_size = "${lookup(var.autoscaling_capacity, "tf-${var.name}-${var.environments[count.index]}-asg-min", lookup(var.autoscaling_capacity_defaults, "${var.environments[count.index]}_min_size", 1))}"

  max_size                  = "${lookup(var.autoscaling_capacity, "tf-${var.name}-${var.environments[count.index]}-asg-max", lookup(var.autoscaling_capacity_defaults, "${var.environments[count.index]}_max_size", 1))}"
  desired_capacity          = "${lookup(var.autoscaling_capacity, "tf-${var.name}-${var.environments[count.index]}-asg-desired", lookup(var.autoscaling_capacity_defaults, "${var.environments[count.index]}_min_size", 1))}"
  wait_for_capacity_timeout = 0
  launch_configuration      = "${element(aws_launch_configuration.xferapp-lc.*.name, count.index)}"
  health_check_type         = "${var.health_check_type}"
  vpc_zone_identifier       = ["${var.subnets}"]
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]

  load_balancers = []

  lifecycle {
    ignore_changes = ["desired_capacity", "max_size", "min_size"]
  }

  target_group_arns = [
    "${element(aws_alb_target_group.alb-target-group.*.arn, count.index)}",
  ]

  termination_policies = [
    "OldestLaunchConfiguration",
    "OldestInstance",
    "Default",
  ]

  tag {
    key                 = "Name"
    value               = "tf-${var.name}-${var.environments[count.index]}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = "${var.environments[count.index]}"
    propagate_at_launch = true
  }

  count = "${var.is_web_app ? length(var.environments) : 0}"
}

resource "aws_autoscaling_policy" "asg_policy_up" {
  depends_on = [
    "aws_autoscaling_group.batch-asg",
    "aws_autoscaling_group.dynamic-asg",
  ]

  name                   = "tf-${var.name}-${var.environments[count.index]}-asg-policy-up"
  autoscaling_group_name = "tf-${var.name}-${var.environments[count.index]}-asg"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 600
  scaling_adjustment     = 4
  count                  = "${var.is_user_app ? length(var.environments) : 0}"
}

resource "aws_autoscaling_policy" "asg_policy_down" {
  depends_on = [
    "aws_autoscaling_group.batch-asg",
    "aws_autoscaling_group.dynamic-asg",
  ]

  name                   = "tf-${var.name}-${var.environments[count.index]}-asg-policy-down"
  autoscaling_group_name = "tf-${var.name}-${var.environments[count.index]}-asg"
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  scaling_adjustment     = -1
  count                  = "${var.is_user_app ? length(var.environments) : 0}"
}

resource "aws_cloudwatch_metric_alarm" "cpu-very-high" {
  depends_on = [
    "aws_autoscaling_group.batch-asg",
    "aws_autoscaling_group.dynamic-asg",
  ]

  alarm_name          = "tf-${var.name}-${var.environments[count.index]}-cpu-very-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "60"
  alarm_description   = "This metric monitors ec2 CPU for very high utilization on agent hosts"
  alarm_actions       = ["${element(var.hipchat_cloudwatch_sns, count.index)}"]

  dimensions {
    AutoScalingGroupName = "tf-${var.name}-${var.environments[count.index]}-asg"
  }

  count = "${length(var.environments)}"
}

resource "aws_cloudwatch_metric_alarm" "cpu-high" {
  alarm_name          = "tf-${var.name}-${var.environments[count.index]}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "40"
  alarm_description   = "This metric monitors ec2 CPU for high utilization on agent hosts"
  alarm_actions       = ["${aws_autoscaling_policy.asg_policy_up.*.arn[count.index]}"]

  dimensions {
    AutoScalingGroupName = "tf-${var.name}-${var.environments[count.index]}-asg"
  }

  count = "${var.is_user_app ? length(var.environments) : 0}"
}

resource "aws_cloudwatch_metric_alarm" "cpu-low" {
  alarm_name          = "tf-${var.name}-${var.environments[count.index]}-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "900"
  statistic           = "Average"
  threshold           = "15"
  alarm_description   = "This metric monitors ec2 CPU for low utilization on agent hosts"
  alarm_actions       = ["${aws_autoscaling_policy.asg_policy_down.*.arn[count.index]}"]

  dimensions {
    AutoScalingGroupName = "tf-${var.name}-${var.environments[count.index]}-asg"
  }

  count = "${var.is_user_app ? length(var.environments) : 0}"
}

resource "aws_codedeploy_deployment_group" "dynamic-dg" {
  depends_on = [
    "aws_codedeploy_app.xferapp",
    "aws_autoscaling_group.batch-asg",
    "aws_autoscaling_group.dynamic-asg",
  ]

  app_name              = "${aws_codedeploy_app.xferapp.name}"
  deployment_group_name = "${var.environments[count.index]}"
  service_role_arn      = "${element(aws_iam_role.xferapp_role_v2.*.arn, count.index)}"

  autoscaling_groups = [
    "tf-${var.name}-${var.environments[count.index]}-asg",
  ]

  trigger_configuration {
    trigger_events     = ["DeploymentFailure", "InstanceFailure", "DeploymentSuccess"]
    trigger_name       = "HipChat Notifications for ${var.environments[count.index]}"
    trigger_target_arn = "${element(var.hipchat_codedeploy_sns, count.index)}"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  count = "${length(var.environments)}"
}

resource "aws_route53_record" "xferapp-domain" {
  depends_on = [
    "aws_alb.alb",
  ]

  zone_id = "${var.zone_id}"
  name    = "tf-${var.name}-${var.environments[count.index]}.${var.zone_name}"
  type    = "CNAME"
  ttl     = "300"

  records = [
    "${element(aws_alb.alb.*.dns_name, count.index)}",
  ]

  count = "${var.is_web_app ? length(var.environments) : 0}"
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
