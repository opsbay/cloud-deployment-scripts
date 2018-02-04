variable "name" {
  description = "Name of the stack, used to construct resource and DNS names"
}

variable "instance_types" {
  description = "Map of instance types by environment, used to construct Auto Scaling Launch Configurations"
  type        = "map"
}

variable "autoscaling_capacity_defaults" {
  description = "Map of auto scaling capacity sizes keyed by environment and type"
  type        = "map"
}

variable "autoscaling_capacity" {
  # This is overriden during a run_terraform where it gets polled from
  # AWS for the exisiting capacities.
  # It will fallback to the defaults above if the ASG does not exist yet.
  description = "Map of auto scaling capacity sizes keyed by asg name."

  type = "map"
}

variable "aws-account-id" {}
variable "aws-account-env" {}
variable "aws-region" {}
variable "vpc_id" {}

variable "subnet_count" {}

variable "subnets" {
  type = "list"
}

variable "elb_subnets" {
  type    = "list"
  default = []
}

variable "alb_subnets" {
  type    = "list"
  default = []
}

variable "amis" {
  type = "map"
}

variable "security_groups" {
  description = "List of SG IDs to use on the instances."
  type        = "list"
}

variable "key_name" {}

variable "user_data" {
  description = "Cloud-init script passed to the launch configuration"
  default     = ""
}

variable "assume_role_for_ssh_auth" {
  description = "If true, assume a role in the hobsons-naviancedev account. If false, assume you're in hobsons-naviancedev"
  default     = false
}

variable "certificate_id" {
  description = "AWS Certificate ID (last path component of ARN)"
  default     = ""
}

variable "is_web_app" {
  description = "Boolean. Whether this is app is a web app. Web apps have a load balancer."
  default     = false
}

variable "is_elb_app" {
  description = "Boolean. Whether this is app uses an ELB."
  default     = false
}

variable "instance_port" {
  description = "Port on the backend"
  default     = 80
}

variable "instance_protocol" {
  description = "Protocol on the backend."
  default     = "HTTP"
}

variable "health_check_target" {
  description = "Health check target for ALB"
  default     = "/"
}

variable "health_check_port" {
  description = "Port for Health Check"
  default     = 80
}

variable "int_elb_instance_port" {
  description = "Port on the backend"
  default     = 80
}

variable "int_elb_instance_protocol" {
  description = "Protocol on the backend."
  default     = "HTTP"
}

variable "int_lb_port" {
  description = "Port on the backend"
  default     = 80
}

variable "int_lb_protocol" {
  description = "Protocol on the backend."
  default     = "HTTP"
}

variable "elb_listeners" {
  description = "List of listeners to be attached to the elb"
  type        = "list"
  default     = []
}

variable "zone_id" {}
variable "zone_name" {}

variable "lb_security_groups" {
  description = "List of SG IDs for the ALB."
  type        = "list"
  default     = []                            # Not every "webapp" in the utilitynode module is a webapp.
}

variable "elb_security_groups" {
  description = "List of SG IDs for the ELB."
  type        = "list"
  default     = []
}

variable "health_check_type" {
  description = "Health check type for ALB"
  default     = "EC2"
}

#### ASG HOOKS ################################################################

variable "use_asg_hook_on_launch" {
  description = "Use asg hook for triggering a lambda function when launching an instance"
  default     = false
}

variable "notification_target_arn" {
  description = "ARN of notification target that ASG will use to notify when an instance is launching"
  default     = ""
}

variable "notification_metadata" {
  description = "Data to include when the ASG sends a message to the notification target"
  default     = "{}"
}

###############################################################################

variable "add_additional_block_device" {
  description = "Wether to add an additional block device to the launch configuration"
  default     = false
}

variable "additional_block_device_size" {
  description = "The size of the additional block device in GB"
  default     = 32
}

variable "encrypt_additional_block_device" {
  description = "Wether to encrypt the additional block device"
  default     = false
}

variable "additional_role_policy_count" {
  description = "The number of additional role policies that will be passed in"
  default     = 0
}

variable "additional_role_policies" {
  description = "A list of additional policies to attach to the iam role"
  type        = "list"
  default     = []
}
