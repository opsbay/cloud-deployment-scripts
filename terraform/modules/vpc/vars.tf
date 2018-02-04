variable "name" {
  description = "Name for the VPC"
  default     = "main"
}

variable "cidr" {
  description = "CIDR Formatted address for the VPC"
  default     = "172.17.0.0/17"
}

variable "cidr_cf_devops_utils" {
  description = "CIDR Formatted address for the VPC DevOps Utils"
  default     = "10.133.0.0/16"
}

variable "enable_hostnames" {
  description = "A boolean flag to enable/disable DNS hostnames in the VPC."
  default     = true
}

variable "enable_dns" {
  description = "A boolean flag to enable/disable DNS support in the VPC."
  default     = true
}

variable "map_public_ip_on_launch" {
  description = "A boolean flag specifying whether or not to map public ips for the public subnet. Only change this if we start explicitly asking for public IPs in autoscaling launch configurations for things that belong in the public subnet."
  default     = true
}

variable "azs" {
  description = "A list of Availability zones in the region"
  default     = []
}

variable "private_app_subnets" {
  description = "A list of private subnets inside the VPC."
  type        = "list"
  default     = []
}

variable "private_rds_subnets" {
  description = "A list of private subnets inside the VPC."
  type        = "list"
  default     = []
}

variable "private_cache_subnets" {
  description = "A list of private subnets inside the VPC."
  type        = "list"
  default     = []
}

variable "subnets" {
  description = "A list of subnets inside the VPC."
  default     = []
}

variable "peer_vpc_cidr_block" {
  description = "The CIDR block of a peer VPC (needed to adjust default security groups for database access and other interoperability)"
}

variable nat_gw_eip_allocs {
  description = "Elastic IP alllocation IDs for the nat gateways."
  type        = "list"
  default     = []
}
