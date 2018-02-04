variable "name" {
  description = "Name for the VPC"
  default     = "main"
}

variable "vpc_id" {
  description = "ID of the VPC"
}

variable "internet_gateway_id" {
  description = "ID of the Internet gateway (if any)"
  default     = ""
}

variable "nat_gateway_ids" {
  description = "IDs of the NAT gateways (if any)"
  type        = "list"
  default     = []
}

variable "create_internet_gateway_route" {
  description = "Create internet gateway route?"
  default     = "0"
}

variable "create_nat_gateway_route" {
  description = "Create nat gateway route?"
  default     = "0"
}

variable "propagating_vgws" {
  description = "A list of the propagating virtual gateways"
  default     = []
  type        = "list"
}

variable "subnets" {
  description = "A list of subnets inside the VPC."
  default     = []
}
