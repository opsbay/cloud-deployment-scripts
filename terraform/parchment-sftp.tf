module "parchment-sftp" {
  source     = "./modules/utilitynode"
  name       = "parchment-sftp"
  amis       = "${var.testapp-centos-7}"
  is_web_app = "false"
  is_elb_app = "false"

  security_groups = [
    "${module.vpc.default_security_group_id}",
    "${aws_security_group.ssh.id}",
    "${aws_security_group.parchment_sftp.id}",
  ]

  # It should be ELB once it's working and stable
  health_check_type   = "EC2"
  health_check_target = "/"

  aws-account-id  = "${var.aws-account-id}"
  aws-account-env = "${substr(var.aws-environment, 16, -1)}"
  aws-region      = "${var.aws-region}"
  vpc_id          = "${module.vpc.vpc_id}"

  instance_types                = "${var.parchment_sftp_instance_types}"
  autoscaling_capacity_defaults = "${var.utilitynode_autoscaling_capacity_defaults}"
  autoscaling_capacity          = "${var.autoscaling_capacity}"

  key_name                 = "${var.ec2_ssh_key_name}"
  assume_role_for_ssh_auth = "${var.assume_role_for_ssh_auth}"

  additional_role_policy_count = 1
  additional_role_policies     = ["${data.template_file.parchment_sftp_eip_policy.rendered}"]

  alb_subnets  = ["${module.vpc.subnets}"]
  elb_subnets  = ["${module.vpc.subnets}"]
  subnets      = ["${module.vpc.subnets}"]
  subnet_count = "${length(module.vpc.subnets)}"
  zone_id      = "${data.aws_route53_zone.testapp_zone.zone_id}"
  zone_name    = "${data.aws_route53_zone.testapp_zone.name}"

  # Cloud-init script passed to the launch configuration
  user_data = "${file("../cloud-init-scripts/parchment-sftp.sh")}"
}

data "template_file" "parchment_sftp_eip_policy" {
  template = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "ec2:AllocateAddress",
            "ec2:AssociateAddress",
            "ec2:DescribeAddresses",
            "ec2:EIPAssociation",
            "ec2:DisassociateAddress"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_security_group" "parchment_sftp" {
  name        = "tf-parchment_sftp"
  description = "Grants access to sftp"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      # whitelist according to https://jira.hobsons.com/browse/NAWS-84
      "10.32.102.0/25",

      "96.46.148.248/30",
      "96.46.148.252/30",
      "96.46.150.232/30",
      "96.46.159.128/27",

      # Now these CIDR's are the equivalent in CIDR to the range:
      # 204.108.64.1 - 204.108.127.255
      # According to https://www.ipconvertertools.com/iprange2cidr#
      "204.108.64.1/32",

      "204.108.64.2/31",
      "204.108.64.4/30",
      "204.108.64.8/29",
      "204.108.64.16/28",
      "204.108.64.32/27",
      "204.108.64.64/26",
      "204.108.64.128/25",
      "204.108.65.0/24",
      "204.108.66.0/23",
      "204.108.68.0/22",
      "204.108.72.0/21",
      "204.108.80.0/20",
      "204.108.96.0/20",
      "204.108.112.0/21",
      "204.108.120.0/22",
      "204.108.124.0/23",
      "204.108.126.0/24",
      "204.108.127.0/25",
      "204.108.127.128/26",
      "204.108.127.192/27",
      "204.108.127.224/28",
      "204.108.127.240/29",
      "204.108.127.248/30",
      "204.108.127.252/31",
      "204.108.127.254/32",
      "204.108.127.255/32",

      # bastion ssh permitted ips
      "4.14.235.30/32",

      "66.161.171.254/32",
      "194.168.123.98/32",
      "203.87.62.226/32",
    ]
  }
}
