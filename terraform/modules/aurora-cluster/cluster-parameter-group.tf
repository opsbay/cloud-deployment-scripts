#==============================================================================
# Cluster parameter group
#==============================================================================
resource "aws_rds_cluster_parameter_group" "aurora-clusterparamgroup" {
  name        = "${var.environment_name}-aurora-56-cluster"
  description = "Aurora 5.6 DB Cluster parameters for Naviance Core"
  family      = "aurora5.6"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }

  parameter {
    name         = "innodb_file_per_table"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "server_audit_events"
    value = "CONNECT"
  }

  parameter {
    name  = "server_audit_logging"
    value = "1"
  }

  parameter {
    name         = "binlog_format"
    value        = "MIXED"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "time_zone"
    value = "US/Eastern"
  }
}
