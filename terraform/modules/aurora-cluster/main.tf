########################
## Cluster definition
########################

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier = "tf-aurora-${var.environment_name}"

  depends_on = [
    "aws_rds_cluster_parameter_group.aurora-clusterparamgroup",
  ]

  vpc_security_group_ids          = ["${var.vpc_rds_security_group_ids}"]
  storage_encrypted               = "true"
  database_name                   = "${var.database_name}"
  master_username                 = "${var.rds_master_username}"
  master_password                 = "${var.rds_master_password}"
  backup_retention_period         = "${var.backup_retention_period}"
  preferred_backup_window         = "02:00-03:00"
  preferred_maintenance_window    = "sun:03:00-sun:04:00"
  db_subnet_group_name            = "${var.vpc_rds_subnet_group_name}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.aurora-clusterparamgroup.name}"
  final_snapshot_identifier       = "${var.environment_name}"

  lifecycle {
    create_before_destroy = true
  }
}

#################################
## Cluster Instances definition
#################################

resource "aws_rds_cluster_instance" "aurora_cluster_instance" {
  count = "${var.cluster_instance_count}"

  identifier              = "${var.environment_name}-${count.index}"
  cluster_identifier      = "${aws_rds_cluster.aurora_cluster.cluster_identifier}"
  depends_on              = ["aws_rds_cluster.aurora_cluster", "aws_db_parameter_group.aurora-paramgroup"]
  instance_class          = "${var.database_instance_type}"
  db_parameter_group_name = "${aws_db_parameter_group.aurora-paramgroup.name}"
  db_subnet_group_name    = "${var.vpc_rds_subnet_group_name}"
  publicly_accessible     = false                                                                          # if true - we'll get the DB wired to the internet and we don't want that.

  lifecycle {
    create_before_destroy = true
  }

  tags {
    "isProduction" = "${var.is_production}"
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu-high" {
  alarm_name          = "tf-${var.database_name}-${var.environment_name}-${lower(var.cluster_roles[count.index])}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "600"
  statistic           = "Average"
  threshold           = "60"
  alarm_description   = "This metric monitors aurora cluster for high CPU utilization"
  alarm_actions       = ["${element(var.hipchat_cloudwatch_sns, count.index)}"]

  dimensions {
    DBClusterIdentifier = "${aws_rds_cluster.aurora_cluster.cluster_identifier}"
    Role                = "${var.cluster_roles[count.index]}"
  }

  count = "${length(var.cluster_roles)}"
}

resource "aws_cloudwatch_metric_alarm" "cpu-critical" {
  alarm_name          = "tf-${var.database_name}-${var.environment_name}-${lower(var.cluster_roles[count.index])}-cpu-critical"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors aurora cluster for critical CPU utilization"
  alarm_actions       = ["${element(var.hipchat_cloudwatch_sns, count.index)}"]

  dimensions {
    DBClusterIdentifier = "${aws_rds_cluster.aurora_cluster.cluster_identifier}"
    Role                = "${var.cluster_roles[count.index]}"
  }

  count = "${length(var.cluster_roles)}"
}
