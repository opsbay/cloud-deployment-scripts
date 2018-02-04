########################
## Variables
########################

variable "environment_name" {
  description = "The environment name for the Aurora cluster. Used to create cluster and instance names."
}

variable "database_name" {
  description = "The name of the default database for the Aurora cluster"
}

variable "vpc_id" {
  description = "The ID of the VPC that the RDS cluster will be created in"
}

variable "vpc_rds_subnet_ids" {
  description = "The ID's of the VPC subnets that the RDS cluster instances will be created in"
}

variable "vpc_rds_security_group_ids" {
  description = "The ID of the security group that should be used for the RDS cluster instances"
  type        = "list"
}

variable "rds_master_username" {
  description = "The master username for the Aurora cluster"
}

variable "rds_master_password" {
  description = "The master password for the Aurora cluster"
}

variable "backup_retention_period" {
  description = "The number of days to keep backups"
}

variable "database_instance_type" {
  description = "The RDS instance type for the Aurora cluster"
}

variable "cluster_instance_count" {
  description = "The number of instances that should exist in the cluster"
}

variable "vpc_rds_subnet_group_name" {
  description = "The name of the VPC's RDS subnet group"
  default     = ""
}

variable "is_production" {
  description = "Boolean. Whether this is instance is being used for production."
}

variable "hipchat_cloudwatch_sns" {
  description = "List of SNS topic ARNs for cloudwatch to hipchat notifications"
  type        = "list"
}

variable "cluster_roles" {
  description = "List of roles for the cluster (will always READER and WRITER)."
  type        = "list"
  default     = ["READER", "WRITER"]
}
