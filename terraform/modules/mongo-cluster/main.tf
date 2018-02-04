resource "aws_instance" "mongo-node" {
  ami                         = "${lookup(var.amis, var.aws-region)}"
  instance_type               = "${lookup(var.instance_types, var.environments[count.index / var.mongo_cluster_size])}"
  associate_public_ip_address = false
  key_name                    = "${var.key_name}"

  user_data            = "${element(data.template_file.cloud-init-template.*.rendered, count.index / var.mongo_cluster_size)}"
  iam_instance_profile = "${element(aws_iam_instance_profile.mongo-node-instances.*.name, count.index / var.mongo_cluster_size)}"

  vpc_security_group_ids = ["${var.security_groups}", "${element(aws_security_group.mongo-cluster-security-group.*.id, count.index / var.mongo_cluster_size)}"]

  subnet_id = "${element(var.private_app_subnets, count.index)}"

  count = "${length(var.environments) * var.mongo_cluster_size}"

  tags {
    Name       = "${format("tf-${var.name}-mongo-${var.environments[count.index / var.mongo_cluster_size]}-%02d", count.index % var.mongo_cluster_size)}"
    SimpleName = "${var.name}-mongo"
    Env        = "${var.environments[count.index / var.mongo_cluster_size]}"
    index      = "${count.index % var.mongo_cluster_size}"
  }

  # This protects this resource from accidental destruction.
  # see: https://www.terraform.io/docs/configuration/resources.html#ignore_changes
  lifecycle {
    ignore_changes = ["ami", "instance_type", "key_name", "user_data"]
  }

  depends_on = [
    "aws_ebs_volume.mongo-data",
    "aws_ebs_volume.mongo-journal",
    "aws_ebs_volume.mongo-log",
  ]
}

resource "aws_ebs_volume" "mongo-data" {
  size              = "${var.mongo_data_size}"
  type              = "gp2"
  encrypted         = true
  availability_zone = "${element(var.private_app_subnets_azs, count.index)}"

  # This protects this resource from accidental destruction.
  # see: https://www.terraform.io/docs/configuration/resources.html#ignore_changes
  lifecycle {
    ignore_changes = ["*"]
  }

  count = "${length(var.environments) * var.mongo_cluster_size}"

  tags {
    Name = "tf-${var.name}-mongo-${var.environments[count.index / var.mongo_cluster_size]}-data-volume"
    Env  = "${var.environments[count.index / var.mongo_cluster_size]}"
  }
}

resource "aws_ebs_volume" "mongo-journal" {
  size              = "${var.mongo_journal_size}"
  type              = "gp2"
  encrypted         = true
  availability_zone = "${element(var.private_app_subnets_azs, count.index)}"

  # This protects this resource from accidental destruction.
  # see: https://www.terraform.io/docs/configuration/resources.html#ignore_changes
  lifecycle {
    ignore_changes = ["*"]
  }

  count = "${length(var.environments) * var.mongo_cluster_size}"

  tags {
    Name = "tf-${var.name}-mongo-${var.environments[count.index / var.mongo_cluster_size]}-journal-volume"
    Env  = "${var.environments[count.index / var.mongo_cluster_size]}"
  }
}

resource "aws_ebs_volume" "mongo-log" {
  size              = "${var.mongo_log_size}"
  type              = "gp2"
  encrypted         = true
  availability_zone = "${element(var.private_app_subnets_azs, count.index)}"

  # This protects this resource from accidental destruction.
  # see: https://www.terraform.io/docs/configuration/resources.html#ignore_changes
  lifecycle {
    ignore_changes = ["*"]
  }

  count = "${length(var.environments) * var.mongo_cluster_size}"

  tags {
    Name = "tf-${var.name}-mongo-${var.environments[count.index / var.mongo_cluster_size]}-log-volume"
    Env  = "${var.environments[count.index / var.mongo_cluster_size]}"
  }
}

resource "aws_volume_attachment" "mongo-data-attach" {
  device_name  = "${var.mongo_data_device}"
  volume_id    = "${element(aws_ebs_volume.mongo-data.*.id, count.index)}"
  instance_id  = "${element(aws_instance.mongo-node.*.id, count.index)}"
  force_detach = false
  skip_destroy = true

  count = "${length(var.environments) * var.mongo_cluster_size}"
}

resource "aws_volume_attachment" "mongo-journal-attach" {
  device_name  = "${var.mongo_journal_device}"
  volume_id    = "${element(aws_ebs_volume.mongo-journal.*.id, count.index)}"
  instance_id  = "${element(aws_instance.mongo-node.*.id, count.index)}"
  force_detach = false
  skip_destroy = true

  count = "${length(var.environments) * var.mongo_cluster_size}"
}

resource "aws_volume_attachment" "mongo-log-attach" {
  device_name  = "${var.mongo_log_device}"
  volume_id    = "${element(aws_ebs_volume.mongo-log.*.id, count.index)}"
  instance_id  = "${element(aws_instance.mongo-node.*.id, count.index)}"
  force_detach = false
  skip_destroy = true

  count = "${length(var.environments) * var.mongo_cluster_size}"
}

resource "aws_route53_record" "mongo-internal" {
  zone_id = "${data.aws_route53_zone.internal.zone_id}"
  name    = "${format("tf-${var.name}-mongo-${var.environments[count.index / var.mongo_cluster_size]}-%02d", count.index % var.mongo_cluster_size)}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${element(aws_instance.mongo-node.*.private_dns, count.index)}"]

  count = "${length(var.environments) * var.mongo_cluster_size}"
}

data "template_file" "cloud-init-template" {
  template = "${file("../cloud-init-scripts/mongo-cluster_init.tpl.sh")}"

  vars {
    awsAccountId = "${var.aws-account-id}"
    environment  = "${var.environments[count.index]}"
    name         = "${var.name}"
  }

  count = "${length(var.environments)}"
}

data "aws_route53_zone" "internal" {
  name         = "local.naviance.com."
  private_zone = "true"
}

data "aws_iam_policy_document" "assume_auth_role" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::253369875794:role/unmanaged-IAM-user-SSH-reader"]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/ssh-auth/*"]
  }

  count = "${var.aws-environment == "hobsons-navianceprod" ? 1 : 0}"
}

data "aws_iam_policy_document" "iam_user_auth" {
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

  count = "${var.aws-environment == "hobsons-naviancedev" ? 1 : 0}"
}

data "aws_vpc" "vpc" {
  id = "${var.vpc_id}"
}

resource "aws_iam_role_policy" "auth_policy" {
  name = "tf-${var.name}-mongo-${var.environments[count.index]}-auth-policy"
  role = "${element(aws_iam_role.mongo-role.*.id, count.index)}"

  # See the if-else statement section of this article
  # https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9
  policy = "${element(concat(data.aws_iam_policy_document.iam_user_auth.*.json, data.aws_iam_policy_document.assume_auth_role.*.json), 0)}"

  count = "${length(var.environments)}"
}

resource "aws_iam_role_policy" "config_policy" {
  name = "tf-${var.name}-mongo-${var.environments[count.index]}-config-policy"
  role = "${element(aws_iam_role.mongo-role.*.id, count.index)}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
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
		"arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/${var.environments[count.index]}/${var.name}-mongo/*",
    "arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/mongo-cluster/*",
		"arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/newrelic/*",
		"arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/nessus/*",
		"arn:aws:s3:::unmanaged-app-config-${var.aws-account-id}/splunk/*"
	  ]
	},
	{
	  "Effect": "Allow",
	  "Action": [
		"ec2:Describe*",
		"tag:getTagKeys",
		"tag:getTagValues",
		"tag:GetResources"
	  ],
	  "Resource": "*"
	}
  ]
}
EOF

  count = "${length(var.environments)}"
}

resource "aws_iam_role" "mongo-role" {
  name = "tf-${var.name}-mongo-${var.environments[count.index]}-role"

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

  count = "${length(var.environments)}"
}

resource "aws_iam_instance_profile" "mongo-node-instances" {
  name = "tf-${var.name}-mongo-${var.environments[count.index]}-instance-profile"
  role = "${element(aws_iam_role.mongo-role.*.name, count.index)}"

  count = "${length(var.environments)}"
}

resource "aws_security_group" "mongo-cluster-security-group" {
  name        = "tf-${var.name}-mongo-${var.environments[count.index]}-sg"
  description = "Allow for per-environment configuration of security group rules"
  vpc_id      = "${var.vpc_id}"

  count = "${length(var.environments)}"
}
