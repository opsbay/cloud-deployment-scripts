#==============================================================================
# Parameter group
#==============================================================================
resource "aws_db_parameter_group" "aurora-paramgroup" {
  name        = "${var.environment_name}-aurora-56"
  description = "Aurora 5.6 DB parameters for Naviance Core"
  family      = "aurora5.6"

  parameter {
    name  = "bulk_insert_buffer_size"
    value = 8388608
  }

  parameter {
    name         = "ft_min_word_len"
    value        = 3
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "innodb_file_format"
    value = "barracuda"
  }

  # This was causing Terraform to regenerate
  # the configuration every time, maybe this one is not valid for aurora
  #parameter {
  #  name  = "innodb_flush_method"
  #  value = "O_DIRECT"
  #  apply_method = "pending-reboot"
  #}

  parameter {
    name  = "innodb_lock_wait_timeout"
    value = 300
  }
  parameter {
    name         = "innodb_open_files"
    value        = 2000
    apply_method = "pending-reboot"
  }

  # This was causing Terraform to regenerate
  # the configuration every time, maybe this one is not valid for aurora
  #parameter {
  #  name  = "key_buffer_size"
  #  value = 16777216
  #}

  parameter {
    name  = "max_allowed_packet"
    value = 16777216
  }
  parameter {
    name  = "max_heap_table_size"
    value = 100663296
  }
  parameter {
    name  = "myisam_sort_buffer_size"
    value = 8388608
  }
  parameter {
    name         = "performance_schema"
    value        = 1
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "query_cache_size"
    value = 0
  }
  parameter {
    name         = "query_cache_type"
    value        = 0
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "table_definition_cache"
    value = 12000
  }
  parameter {
    name  = "table_open_cache"
    value = 12000
  }
  parameter {
    name  = "tmp_table_size"
    value = 100663296
  }
  parameter {
    name  = "wait_timeout"
    value = 600
  }
  parameter {
    name  = "connect_timeout"
    value = 10
  }
  parameter {
    name  = "log_bin_trust_function_creators"
    value = 1
  }
  parameter {
    name  = "optimizer_switch"
    value = "semijoin=off"
  }
  parameter {
    name  = "optimizer_search_depth"
    value = "5"
  }
  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  parameter {
    name  = "long_query_time"
    value = "7"
  }
  parameter {
    name  = "general_log"
    value = "${var.is_production == "true" ? "0" : "1"}"
  }
  parameter {
    name  = "event_scheduler"
    value = "ON"
  }
}
