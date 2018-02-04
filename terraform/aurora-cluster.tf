resource "aws_security_group" "aurora-private-from-bigdata-peer-vpc" {
  name        = "tf-aurora-private-from-bigdata-peer-vpc"
  description = "Allows access to the database from the BigData peer VPC"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = ["${var.cidr_bigdata_vpc}"]
  }
}

module "aurora-cluster-v2" {
  source = "./modules/aurora-cluster"

  environment_name = "${var.aurora_environment_name}"

  database_instance_type = "${var.aurora_database_instance_type}"

  vpc_id                     = "${module.vpc.vpc_id}"
  vpc_rds_subnet_ids         = "${join(",",module.vpc.subnets)}"
  vpc_rds_security_group_ids = ["${aws_security_group.aurora-private.id}", "${aws_security_group.aurora-private-from-vpn.id}", "${aws_security_group.aurora-private-from-peer-vpc.id}", "${aws_security_group.aurora-private-from-bigdata-peer-vpc.id}"]
  vpc_rds_subnet_group_name  = "${module.vpc.private_rds_subnet_group_name}"

  rds_master_username = "${var.aurora_rds_master_username}"
  rds_master_password = "${var.aurora_rds_master_password}"

  database_name = "${var.aurora_database_name}"

  backup_retention_period = "${var.aurora_backup_retention_period}"
  cluster_instance_count  = "${var.aurora_cluster_instance_count}"

  is_production = "${var.aws-environment == "hobsons-navianceprod" ? "true" : "false"}"

  hipchat_cloudwatch_sns = ["${aws_sns_topic.hipchat_cloudwatch_sns.*.arn}"]
}

module "aurora-cluster-perftest-v1" {
  source = "./modules/aurora-cluster"

  environment_name = "${var.aurora_environment_name_perftest}"

  database_instance_type = "${var.aurora_database_instance_type_perftest}"

  vpc_id                     = "${module.vpc.vpc_id}"
  vpc_rds_subnet_ids         = "${join(",",module.vpc.subnets)}"
  vpc_rds_security_group_ids = ["${aws_security_group.aurora-private.id}", "${aws_security_group.aurora-private-from-vpn.id}", "${aws_security_group.aurora-private-from-peer-vpc.id}"]
  vpc_rds_subnet_group_name  = "${module.vpc.private_rds_subnet_group_name}"

  rds_master_username = "${var.aurora_rds_master_username_perftest}"
  rds_master_password = "${var.aurora_rds_master_password_perftest}"

  database_name = "${var.aurora_database_name_perftest}"

  backup_retention_period = "${var.aurora_backup_retention_period_perftest}"
  cluster_instance_count  = "${var.aurora_cluster_instance_count_perftest}"

  is_production = "${var.aws-environment == "hobsons-navianceprod" ? "true" : "false"}"

  hipchat_cloudwatch_sns = ["${aws_sns_topic.hipchat_cloudwatch_sns.*.arn}"]
}
