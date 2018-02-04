variable "name" {
  description = "Name of the stack, used to construct resource and DNS names"
}

variable "codedeploy_path" {
  description = "Name that the codedeply bucket refers to"
}

variable "environments" {
  description = "List of environments (qa, staging, etc), used to construct resource and DNS names"
  type        = "list"
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

variable "zone_id" {}
variable "zone_name" {}

variable "vpc_id" {}

variable "amis" {
  type = "map"
}

variable "aws-region" {}

variable "subnets" {
  type = "list"
}

variable "elb_subnets" {
  type    = "list"
  default = []
}

variable "subnet_count" {}

variable "key_name" {}

variable "security_groups" {
  description = "List of SG IDs to use on the instances."
  type        = "list"
}

variable "lb_security_groups" {
  description = "List of SG IDs for the ALB."
  type        = "list"
  default     = []                            # Not every "webapp" in the webapp module is a webapp.
}

variable "instance_protocol" {
  description = "Protocol on the backend."
  default     = "HTTP"
}

variable "instance_port" {
  description = "Port on the backend"
  default     = 80
}

variable "certificate_id" {
  description = "AWS Certificate ID map with 'name-env'"
  type        = "map"
  default     = {}
}

variable "use_http_listener" {
  description = "Enable HTTP listeners"
  default     = "false"
}

variable "health_check_type" {
  description = "Health check type for ALB"
  default     = "EC2"
}

variable "health_check_target" {
  description = "Health check target for ALB"
  default     = ""
}

variable "health_check_port" {
  description = "Port for Health Check"
  default     = 80
}

variable "health_check_protocol" {
  description = "Protocol for Health Check (Only Supports HTTP/S)"
  default     = "HTTP"
}

variable "aws-account-id" {}

variable "is_user_app" {
  description = "Boolean. Whether this is a user-facing app, like FC or Succeed, or a back-end service or API."
  default     = "false"
}

variable "is_web_app" {
  description = "Boolean. Whether this is app is a web app. Web apps have a load balancer. Batch applications do not. For safety's sake, this is false by default, yes this is ironic given that the name of this module is webapp."
  default     = "false"
}

variable "is_internal" {
  description = "Boolean. Whether this is app's load balancer should have a public IP address. Default to true for safety. Set this to false to get an internet_facing alb. Has no effect if 'is_web_app=false'"
  default     = "true"
}

variable "assume_role_for_ssh_auth" {
  description = "If true, assume a role in the hobsons-naviancedev account. If false, assume you're in hobsons-naviancedev"
  default     = "false"
}

variable "root_block_device_size" {
  description = "The size in gigabytes of the root block device for EC2 servers"
  default     = 30
}

variable "hipchat_cloudwatch_sns" {
  description = "List of SNS topic ARNs for cloudwatch to hipchat notifications"
  type        = "list"
}

variable "hipchat_codedeploy_sns" {
  description = "List of SNS topic ARNs for codedeploy to hipchat notifications"
  type        = "list"
}

variable "user_data" {
  description = "User data passed to cloud-init"
  default     = ""
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
