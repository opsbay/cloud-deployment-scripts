variable "name" {
  description = "VPC VPN gateway name"
  default     = "main"
}

variable "vpc_id" {
  description = "VPC id to associate with the VPN gateway"
}
