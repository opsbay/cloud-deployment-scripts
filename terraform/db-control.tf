module "db-control" {
  source = "./modules/utilitynode"
  name   = "db-control"
  amis   = "${var.testapp-centos-7}"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
  ]

  aws-account-id  = "${var.aws-account-id}"
  aws-account-env = "${substr(var.aws-environment, 16, -1)}"
  aws-region      = "${var.aws-region}"
  vpc_id          = "${module.vpc.vpc_id}"

  instance_types                = "${var.db_control_instance_types}"
  autoscaling_capacity_defaults = "${var.utilitynode_autoscaling_capacity_defaults}"
  autoscaling_capacity          = "${var.autoscaling_capacity}"
  is_web_app                    = "false"

  key_name                     = "${var.ec2_ssh_key_name}"
  assume_role_for_ssh_auth     = "${var.assume_role_for_ssh_auth}"
  additional_role_policy_count = 1

  additional_role_policies = [
    "${data.template_file.db_control_bucket_policy_template.rendered}",
  ]

  subnets      = ["${module.vpc.private_app_subnets}"]
  subnet_count = "${length(module.vpc.subnets)}"
  zone_id      = "${data.aws_route53_zone.testapp_zone.zone_id}"
  zone_name    = "${data.aws_route53_zone.testapp_zone.name}"

  add_additional_block_device     = true
  additional_block_device_size    = 1000
  encrypt_additional_block_device = true

  # Cloud-init script passed to the launch configuration
  user_data = "${file("../cloud-init-scripts/db-control_init.sh")}"
}

resource "aws_s3_bucket" "db_control_bucket" {
  bucket = "tf-db-control-storage-${var.aws-account-id}"
  acl    = "private"
}

data "template_file" "db_control_bucket_policy_template" {
  template = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
     {
       "Effect": "Allow",
       "Action": ["s3:ListBucket"],
       "Resource": ["$${db_control_bucket_arn}"]
     },
     {
       "Effect": "Allow",
       "Action": [
         "s3:PutObject",
         "s3:GetObject",
         "s3:DeleteObject"
       ],
       "Resource": ["$${db_control_bucket_arn}/*"]
     }
   ]
 }
EOF

  vars {
    db_control_bucket_arn = "${aws_s3_bucket.db_control_bucket.arn}"
  }
}
