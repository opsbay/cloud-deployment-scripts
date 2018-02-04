variable "name" {
  description = "Name of the mongo cluster, used to construct resource and DNS names"
}

variable "environments" {
  description = "List of environments (qa, staging, etc), used to construct resource and DNS names"
  type        = "list"
}

variable aws-environment {
  description = "AWS Environment Name"
}

variable "aws-account-id" {}

variable "aws-region" {}

variable "vpc_id" {}

variable "key_name" {}

variable "amis" {
  type = "map"
}

variable "private_app_subnets" {
  type = "list"
}

variable "private_app_subnets_azs" {
  type = "list"
}

variable "instance_types" {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"
}

variable "security_groups" {
  description = "List of SG IDs to use on the instances."
  type        = "list"
}

# WARNING: This is currently hardcoded to 3 elsewhere!
variable "mongo_cluster_size" {
  description = "Number of mongo instances"
  default     = 3
}

variable "mongo_data_size" {
  description = "Size of EBS Volume for mongo data (GB)"
  default     = 250
}

variable "mongo_journal_size" {
  description = "Size of EBS Volume for mongo journal (GB)"
  default     = 100
}

variable "mongo_log_size" {
  description = "Size of EBS Volume for mongo log (GB)"
  default     = 100
}

variable "mongo_data_device" {
  description = "Block device name for mongo dataebs volume"
  default     = "/dev/sdg"
}

variable "mongo_journal_device" {
  description = "Block device name for mongo journal ebs volume"
  default     = "/dev/sdh"
}

variable "mongo_log_device" {
  description = "Block device name for mongo log ebs volume"
  default     = "/dev/sdi"
}
