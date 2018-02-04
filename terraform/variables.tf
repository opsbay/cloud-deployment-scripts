# variables.tf
#
# Top-level configuration variables for Terraform.
# Many of these are expected to be overriden by tvfars files.
#
# Account, region, and VPC-specific values should live here
# instead of being hard-coded in modules or in other top-level
# files.
#
# The run_terraform.sh file downloads several variable files
# from S3 that override some of these values. Please note in
# this file the expected source of those runtime variables.
#
# Let's keep this organized with verbose comments and section
# headers, please.

###### AWS Account and Region
# These are set by run_terraform.sh

variable aws-region {
  description = "AWS Region"
  default     = "us-east-1"
}

variable aws-account-id {
  description = "AWS Account ID"
  default     = "253369875794"
}

variable aws-environment {
  description = "AWS Environment Name"
  default     = "hobsons-naviancedev"
}

###### Baseline AMI configurations
# These are overriden in vpc-id-NNNNNNNNNNNN.tfvars at runtime
# Files of that format are the build products of packer, stored in S3.

variable testapp-ubuntu {
  type = "map"

  default = {
    us-east-1 = "ami-15079703"
  }
}

variable testapp-centos-6 {
  type = "map"

  default = {
    us-east-1 = "ami-fea73de8"
  }
}

variable testapp-centos-7 {
  type = "map"

  default = {
    us-east-1 = "ami-cfe778d9"
  }
}

variable alert-logic-appliance {
  description = "Alertlogic TMC - P12 --> Private AMI!"
  type        = "map"

  default = {
    us-east-1 = "ami-c2a8f7b9"
  }
}

###### Networking: VPC, Routing Tables, and CIDR Ranges

## VPC peering variables

# These are set in vpc-id-NNNNNNNNNNNN.tfvars
variable corp_vpc_id {
  description = "VPC ID for the main vpc in the account"
}

variable corp_rt_id_1 {
  description = "Routing table ID for the main vpc in the account"
}

variable devtools_vpc_id {
  description = "VPC ID for the development tools VPC in the account (the one managed by CloudFormation)"

  # Need to specify a default so we can optionally
  # ignore this in production.
  # Where it is needed, it will be explicitly set.
  default = "vpc-override"
}

variable devtools_vpc_rt_jenkins_agents {
  description = "Routing table ID for the development tools VPC in the account"

  # Need to specify a default so we can optionally
  # ignore this in production.
  # Where it is needed, it will be explicitly set.
  default = "rtb-override"
}

## main managed VPC variables

variable vpc_cidr {
  description = "CIDR network for main managed VPC"
  default     = "10.87.0.0/16"
}

variable vpc_subnets {
  description = "Subnet definitions for main managed VPC"
  type        = "list"

  default = [
    "10.87.0.0/22",
    "10.87.4.0/22",
    "10.87.8.0/22",
    "10.87.12.0/22",
  ]
}

variable vpc_private_app_subnets {
  description = "Private subnet definitions for Application servers in main managed VPC"
  type        = "list"

  default = [
    "10.87.16.0/22",
    "10.87.20.0/22",
    "10.87.24.0/22",
    "10.87.28.0/22",
  ]
}

variable vpc_private_rds_subnets {
  description = "Private subnet definitions for Database servers in main managed VPC"
  type        = "list"

  default = [
    "10.87.32.0/22",
    "10.87.36.0/22",
    "10.87.40.0/22",
    "10.87.44.0/22",
  ]
}

variable vpc_private_cache_subnets {
  description = "Private subnet definitions for ElastiCache servers in main managed VPC"
  type        = "list"

  default = [
    "10.87.48.0/22",
    "10.87.52.0/22",
    "10.87.56.0/22",
    "10.87.60.0/22",
  ]
}

variable vpc_azs {
  description = "Subnet definitions for main managed VPC"
  type        = "list"

  default = [
    "us-east-1a",
    "us-east-1c",
    "us-east-1d",
    "us-east-1e",
  ]
}

# See https://jira.hobsons.com/browse/NAWS-539
# These are used for whitelisting to external vendors.
# Default values here are for hobsons-naviancedev, this
# must be overridden for other AWS accounts.
variable nat_gw_eip_allocs {
  description = "Elastic IP alllocation IDs for the nat gateways"
  type        = "list"

  default = [
    "eipalloc-07e8ab37",
    "eipalloc-26809616",
    "eipalloc-cde8abfd",
    "eipalloc-7c84924c",
  ]
}

## IP CIDR ranges
# These get used by security groups and VPC definitions
# TODO: review these before going to production
# ******************* WARNING CONSULT mark.jenkins@hobsons.com
# ******************* or the person currently in charge of Naviance security
# ******************* if Mark is unavailable (see: Infosec) before changing
# ******************* any of these groups.
variable cidr_whitelist {
  description = "Whitelist for direct network access to services"
  type        = "list"

  default = [
    "4.14.235.30/32",    # Hobsons Arlington Office - Level 3
    "66.161.171.254/32", # Hobsons Ohio Office - Fuse
    "67.131.242.131/32", # Hobsons SJC Datacenter
    "194.168.123.98/32", # Hobsons Publishing UK (reported by Dan Batiste) - Virgin Media
    "203.87.62.226/32",  # Hobsons Australia (reported by Dan Batiste) - TPG
  ]
}

variable cidr_learnapi_NAT_whitelist {
  description = "Whitelist for NATd IPs access to learnapi services"
  type        = "list"

  default = [
    "52.7.202.123/32",   # IAM-NAT01-US-East-1a
    "52.1.87.239/32",    # IAM-NAT01-US-East-1e
    "52.4.242.187/32",   # IAM-NAT02-US-East-1a
    "52.7.119.232/32",   # IAM-NAT02-US-East-1e
    "54.88.249.134/32",  # LH-NAT01-US-East-1a
    "54.88.254.206/32",  # LH-NAT01-US-East-1d
    "54.164.155.184/32", # LH-NAT02-US-East-1a
    "54.86.121.251/32",  # LH-NAT02-US-East-1d
    "54.164.231.10/32",  # LH-NAT03-US-East-1a
    "54.164.158.248/32", # LH-NAT03-US-East-1d
    "54.152.203.130/32", # TestPrep-NAT01-US-East-1a
    "54.174.253.22/32",  # TestPrep-NAT01-US-East-1e
    "52.5.178.248/32",   # TestPrep-NAT02-US-East-1a
    "52.6.92.35/32",     # TestPrep-NAT01-US-East-1e
  ]
}

variable logicmonitor_whitelist {
  description = "Whitelist for Logic Monitor Service Checks"
  type        = "list"

  default = [
    "54.169.40.94/32",   # Asia - Singapore
    "54.255.185.191/32", # Asia - Singapore
    "52.77.35.229/32",   # Asia - Singapore
    "52.77.66.61/32",    # Asia - Singapore
    "52.31.2.18/32",     # EU - Dublin
    "54.72.173.169/32",  # EU - Dublin
    "52.19.116.239/32",  # EU - Dublin
    "52.49.248.100/32",  # EU - Dublin
    "52.62.46.109/32",   # Australia - Sydney
    "52.62.171.154/32",  # Australia - Sydney
    "52.9.88.181/32",    # US - San Francisco
    "52.9.152.239/32",   # US - San Francisco
    "74.201.65.4/32",    # US - Los Angeles
    "74.201.65.8/32",    # US - Los Angeles
    "52.0.173.190/32",   # US - Washington DC
    "52.21.6.22/32",     # US - Washington DC
    "69.25.43.50/32",    # US - Washington DC
  ]
}

variable cidr_devtools {
  description = "Whitelist for DevTools VPC network (useful for SSH from bastion host)"
  type        = "list"

  default = [
    "10.133.0.0/20",  # subnet-042ac228 | A public
    "10.133.32.0/20", # subnet-042ac228 | B public
    "10.133.64.0/20", # subnet-2b886e71 | C public
  ]
}

variable cidr_devtools_vpc_nat_gw {
  description = "Whitelist for DevTools VPC network (useful for SSH from bastion host)"
  type        = "list"

  default = [
    "52.23.103.23/32",
  ]
}

variable cidr_bigdata_vpc {
  description = "CIDR network for BigData VPC"
  type        = "list"

  default = [
    "10.78.0.0/16", # 626707481977 BigDataStaging vpc
  ]
}

variable edocsmongo_whitelist {
  description = "Whitelist for edocsmongo"
  type        = "map"

  default = {
    qa         = ["10.24.168.152/32"]
    staging    = ["127.0.0.1/32"]
    preprod    = ["127.0.0.1/32"]
    production = ["10.32.202.0/25"]
  }
}

###### Route 53 related variables
# The keys in this map should correspond to a value held in the aws-environment variable
variable "domain" {
  description = "Domain name hosted by Route 53"

  default = {
    hobsons-naviancedev  = "mango.naviance.com"
    hobsons-navianceprod = "papaya.naviance.com"
  }
}

variable certificate_id {
  description = "Map of Certificate IDs used for provisioning ELBs"

  default = {
    # star - the default (same as *.mango.naviance.com in hobsons-naviancedev)
    star = "arn:aws:acm:us-east-1:253369875794:certificate/a9899d2d-5885-4103-b5af-c36530c5fbf4"

    # *.mango.naviance.com
    hobsons-naviancedev = "arn:aws:acm:us-east-1:253369875794:certificate/a9899d2d-5885-4103-b5af-c36530c5fbf4"

    # *.papaya.naviance.com
    hobsons-navianceprod = "arn:aws:acm:us-east-1:989043056009:certificate/9489edd4-0063-45dc-837f-4df87ecf45b4"

    # Other values to specify in prod
    # succeed
    # connection

    # star-dev-naviance (same as *.dev.naviance.com)
    star-dev-naviance = "arn:aws:acm:us-east-1:253369875794:certificate/2c8a9250-dbed-455d-afbf-2be13bbc8ac0"
    # legacyapi - use *.dev.naviance.com cert for qa NAWS-66
    legacyapi-qa = "arn:aws:acm:us-east-1:253369875794:certificate/2c8a9250-dbed-455d-afbf-2be13bbc8ac0"
    # iambridge - use *.dev.naviance.com cert for qa NAWS-66
    iambridge-qa = "arn:aws:acm:us-east-1:253369875794:certificate/a9899d2d-5885-4103-b5af-c36530c5fbf4"
    # servicesapi - use *.dev.naviance.com cert for qa NAWS-919
    servicesapi-56-qa = "arn:aws:acm:us-east-1:253369875794:certificate/2c8a9250-dbed-455d-afbf-2be13bbc8ac0"
  }
}

###### Environments
# The webapp module has support for defining multiple environments
# using the same templates. This lists those.
# Expect this to be overridden in environments-NNNNNNNNNNNN.tfvars at runtime

variable environments {
  description = "A list of environments to maintain for applications"
  type        = "list"

  default = [
    "qa",
    "staging",
  ]
}

variable app_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "c4.2xlarge"
    production = "c4.2xlarge"
  }
}

variable app_56_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "c5.xlarge"
    production = "c5.xlarge"
  }
}

variable app_internal_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "m4.large"
    production = "m4.large"
  }
}

variable service_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "m4.large"
    production = "m4.large"
  }
}

variable area51_cron_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "t2.medium"
    production = "t2.medium"
  }
}

variable njq_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "c4.4xlarge"
    production = "c4.4xlarge"
  }
}

variable lm_collector_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    dev  = "m4.large"
    prod = "m4.large"
  }
}

variable db_control_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    dev  = "m4.large"
    prod = "m4.large"
  }
}

variable edocsconfig_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "t2.medium"
    production = "t2.medium"
  }
}

variable edocsdata_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "m4.large"
    production = "m4.large"
  }
}

variable edocsinst_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "m4.large"
    production = "m4.large"
  }
}

variable edocsmtm_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.xlarge"
    staging    = "t2.xlarge"
    preprod    = "c5.4xlarge"
    production = "c5.4xlarge"
  }
}

variable edocsreceive_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "m4.large"
    production = "m4.large"
  }
}

variable edocssub_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "c5.2xlarge"
    production = "c5.2xlarge"
  }
}

variable edocssubp_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "c5.xlarge"
    production = "c5.xlarge"
  }
}

variable edocsupload_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    qa         = "t2.medium"
    staging    = "t2.medium"
    preprod    = "c5.xlarge"
    production = "c5.xlarge"
  }
}

variable utilitynode_autoscaling_capacity_defaults {
  description = "Map of auto scaling capacity sizes keyed by environment and type"
  type        = "map"

  default = {
    dev_min_size  = 1
    dev_max_size  = 1
    prod_min_size = 1
    prod_max_size = 1
  }
}

variable alertlogic_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    dev  = "c3.xlarge"
    prod = "c3.xlarge"
  }
}

variable mailcatcher_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    dev  = "m4.large"
    prod = "m4.large"
  }
}

variable parchment_sftp_instance_types {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"

  default = {
    dev  = "t2.medium"
    prod = "m4.large"
  }
}

variable "app_autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type"
  type        = "map"

  default = {
    qa_min_size         = 2
    qa_max_size         = 6
    staging_min_size    = 2
    staging_max_size    = 6
    preprod_min_size    = 4
    preprod_max_size    = 28
    production_min_size = 4
    production_max_size = 28
  }
}

variable "app_internal_autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type for internal applications"
  type        = "map"

  default = {
    qa_min_size         = 1
    qa_max_size         = 1
    staging_min_size    = 1
    staging_max_size    = 1
    preprod_min_size    = 2
    preprod_max_size    = 2
    production_min_size = 2
    production_max_size = 2
  }
}

variable "service_autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type"
  type        = "map"

  default = {
    qa_min_size         = 2
    qa_max_size         = 3
    staging_min_size    = 2
    staging_max_size    = 3
    preprod_min_size    = 3
    preprod_max_size    = 12
    production_min_size = 3
    production_max_size = 12
  }
}

variable "njq_autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type"
  type        = "map"

  default = {
    qa_min_size         = 1
    qa_max_size         = 3
    staging_min_size    = 1
    staging_max_size    = 3
    preprod_min_size    = 1
    preprod_max_size    = 10
    production_min_size = 1
    production_max_size = 10
  }
}

variable "edocs_autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type for edocs"
  type        = "map"

  default = {
    qa_min_size         = 2
    qa_max_size         = 2
    staging_min_size    = 2
    staging_max_size    = 2
    preprod_min_size    = 2
    preprod_max_size    = 2
    production_min_size = 2
    production_max_size = 2
  }
}

variable "provisioners_autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type for provisioners"
  type        = "map"

  default = {
    qa_min_size         = 1
    qa_max_size         = 1
    staging_min_size    = 1
    staging_max_size    = 1
    preprod_min_size    = 1
    preprod_max_size    = 1
    production_min_size = 1
    production_max_size = 1
  }
}

variable "area51_cron_autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type for area51 cron groups"
  type        = "map"

  default = {
    qa_min_size         = 1
    qa_max_size         = 1
    staging_min_size    = 1
    staging_max_size    = 1
    preprod_min_size    = 1
    preprod_max_size    = 1
    production_min_size = 1
    production_max_size = 1
  }
}

variable "single_autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type for cron single groups (legacy or not)"
  type        = "map"

  default = {
    qa_min_size         = 1
    qa_max_size         = 1
    staging_min_size    = 1
    staging_max_size    = 1
    preprod_min_size    = 1
    preprod_max_size    = 1
    production_min_size = 1
    production_max_size = 1
  }
}

variable "zero_autoscaling_capacity_defaults" {
  description = "A zeroed out capacity default"
  type        = "map"

  default = {
    qa_min_size         = 0
    qa_max_size         = 0
    staging_min_size    = 0
    staging_max_size    = 0
    preprod_min_size    = 0
    preprod_max_size    = 0
    production_min_size = 0
    production_max_size = 0
  }
}

variable "autoscaling_capacity" {
  # These values will be generated at runtime by run_terraform
  # and must be allowed to fall back gracefully to other variables
  # if the asg does not exist.
  description = "Map of auto scaling capacity keyed by asg name"

  type = "map"
}

variable "aurora_environment_name" {
  description = "The environment name for the Aurora cluster. Used to create cluster and instance names."
  default     = "qa-v2"
}

variable "aurora_database_instance_type" {
  description = "The RDS instance type for the Aurora cluster"
  default     = "db.r4.large"
}

variable "aurora_rds_master_password" {
  description = "The master password for the Aurora cluster"

  # This must be specified outside a version
  # controlled file, preferably in the environments-XXXX.tf file stored in S3.
}

variable "aurora_rds_master_username" {
  description = "The master username for the Aurora cluster"
  default     = "testappdb"
}

variable "aurora_database_name" {
  description = "The name of the default database for the Aurora cluster"
  default     = "testappdb"
}

variable "aurora_backup_retention_period" {
  description = "How many days should we keep backups? (1 is the default)"
  default     = "1"
}

variable "aurora_cluster_instance_count" {
  description = "How many instances should we have in the cluster?"
  default     = "2"
}

variable "aurora_environment_name_perftest" {
  description = "The environment name for the secondary Aurora cluster. Used to create cluster and instance names."
  default     = "perftest"
}

variable "aurora_database_instance_type_perftest" {
  description = "The RDS instance type for the secondary Aurora cluster"
  default     = "db.r3.large"
}

variable "aurora_rds_master_password_perftest" {
  description = "The master password for the secondary Aurora cluster"

  # This must be specified outside a version
  # controlled file, preferably in the environments-XXXX.tf file stored in S3.
}

variable "aurora_rds_master_username_perftest" {
  description = "The master username for the secondary Aurora cluster"
  default     = "changeme"
}

variable "aurora_database_name_perftest" {
  description = "The name of the default database for the secondary Aurora cluster"
  default     = "changeme"
}

variable "aurora_backup_retention_period_perftest" {
  description = "How many days should we keep backups? (1 is the default) (For the secondary cluster)"
  default     = "1"
}

variable "aurora_cluster_instance_count_perftest" {
  description = "How many instances should we have in the cluster? (For the secondary cluster)"
  default     = "2"
}

variable "elasticache_node_type" {
  description = "The instance type used to construct the elasticache cluster"
  default     = "cache.t2.small"
}

variable "elasticache_num_cache_nodes" {
  description = "The number of instances used to construct the elasticache cluster"
  default     = 1
}

variable "elasticache_node_type_perftest" {
  description = "The instance type used to construct the secondary elasticache cluster"
  default     = "cache.t2.small"
}

variable "elasticache_num_cache_nodes_perftest" {
  description = "The number of instances used to construct the secondary elasticache cluster"
  default     = 1
}

variable "datacenter-sjc-static_ip_prefix" {
  description = "CIDR prefixes for the SJC static IPs"

  default = [
    "10.24.168.0/24",
  ]
}

variable "datacenter-iad-static_ip_prefix" {
  description = "CIDR prefixes for the IAD1K/DC4 static IPs"

  default = [
    "10.32.10.0/25",
    "10.32.102.0/25",
    "10.32.108.0/25",
    "10.32.168.0/24",
  ]
}

variable "datacenter-database_ip_prefix" {
  description = "CIDR prefixes for the datacenter databases, for replication"

  default = [
    "10.32.204.0/24",
    "10.32.201.0/24",
  ]
}

variable "ec2_ssh_key_name" {
  description = "The name of the key used to configure EC2 instances for SSH access"
  default     = "testapp"
}

###### Route 53 variables for hosts on private networks

variable "dns_mailcatcher_sjc_address" {
  description = "The IP address of the dev mail server (Mailcatcher) in the SJC data center"
  default     = "10.24.168.87"
}

variable "dns_active_directory_sjc_address" {
  description = "The IP address of the Active Directory server (varies by account, ads.hobsons.local in prod)"
  default     = "10.24.168.71"
}

variable "dns_active_directory_iad_address" {
  description = "The IP address of the Active Directory server (varies by account, ads.hobsons.local in prod)"
  default     = "10.32.168.87"
}

variable "dns_strongmail_iad_address" {
  description = "The IP address of the prod mail server (Strongmail) in the IAD data center"
  default     = "10.32.168.17"
}

variable "dns_strongmail_dev_iad_address" {
  description = "The IP address of the dev mail server (Strongmail) in the IAD data center"
  default     = "tf-int-mailcatcher-dev.mango.naviance.com"
}

variable "dns_edocs_mtm_iad_address" {
  description = "The IP address of the eDocs Multiple Transcript Manager (iad1kpu-edocsmtm02.hobsons.local in prod)"
  default     = "10.32.102.17"
}

variable "dns_edocs_srcv_iad_address" {
  description = "The IP address of the eDocs Upload API (iad1kpu-edocsrcv01.hobsons.local in prod)"
  default     = "10.32.102.19"
}

variable "dns_edocs_inst_iad_address" {
  description = "The IP address of the eDocsi Internally Cached Data (iad1kpu-edocsinst01.hobsons.local in prod)"
  default     = "10.32.102.14"
}

variable "dns_edocs_load_balancer_address" {
  description = "The IP address of the edocs API load balancer (iad1kpu-edocs-lb.hobsons.local in prod)"
  default     = "10.32.168.45"
}

variable "assume_role_for_ssh_auth" {
  description = "Boolean used to determine which IAM policy to apply to EC2 instances for authentication"
  default     = false
}

variable "dns_edocs_mongodb_01_address" {
  description = "The IP address of the eDocs mongodb server 01 (iad1kpd-edocsmongo01.hobsons.local)"
  default     = "10.32.202.11"
}

variable "dns_edocs_mongodb_02_address" {
  description = "The IP address of the eDocs mongodb server 01 (iad1kpd-edocsmongo02.hobsons.local)"
  default     = "10.32.202.12"
}

variable "dns_edocs_mongodb_03_address" {
  description = "The IP address of the eDocs mongodb server 01 (iad1kpd-edocsmongo03.hobsons.local)"
  default     = "10.32.202.13"
}

variable "dns_parchment_prod_address" {
  description = "The IP address of the load balancer serving SFTP parchment server"
  default     = "10.32.168.65"
}

###### WAF Rule ID Configurations
# These are overriden waf-rule-ids-NNNNNNNNNNNN.tfvars at runtime
# These rules are generated by the ./bin/manage-cf-waf-stack.sh script

# This can have a default as Production will not use it
variable "unmanaged-github-webhook-access" {
  description = "Pre-existing GitHub Webhook rule id"
  default     = "6db71513-2225-4964-9b24-18a1aeb14f09"
}

# This can have a default as Production will not use it
variable "unmanaged-hobsons-rule" {
  description = "Pre-existing whitelist rule id"
  default     = "d507feec-d83a-474f-bd0e-396600e6c187"
}

variable "cf-waf-stack-waf-ip-reputation-lists-rule-1" {
  description = "IP Reputation List 1 rule id"
}

variable "cf-waf-stack-waf-ip-reputation-lists-rule-2" {
  description = "IP Reputation List 2 rule id"
}

variable "cf-waf-stack-whitelist-rule" {
  description = "Manual whitelist rule id"
}

variable "cf-waf-stack-bad-bot-rule" {
  description = "Bad bot rule id"
}

variable "cf-waf-stack-sql-injection-rule" {
  description = "SQL injection rule id"
}

variable "cf-waf-stack-blacklist-rule" {
  description = "Manual blacklist rule id"
}

variable "cf-waf-stack-auto-block-rule" {
  description = "Auto Block rule id"
}

variable "cf-waf-stack-xss-rule" {
  description = "Cross-site scripting rule id"
}

# https://jira.hobsons.com/browse/NAWS-1114
variable jenkins_security_groups {
  description = "In which security group do Jenkins executors live? Probably set in an environment-specific config."
  type        = "list"
  default     = []
}
