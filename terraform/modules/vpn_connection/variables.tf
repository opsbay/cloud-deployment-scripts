variable "create_vpn_connection" {
  description = "If set to true, create an vpn connection for production. or create connection for qa"
  default     = false
}

variable "vpn_gateway_id" {
  description = "VPN Gateway ID to use"
}

variable "customer_gateway_address" {
  description = "The IP address of the gateway's Internet-routable external interface."
}

variable "bgp_asn" {
  description = "The gateway's Border Gateway Protocol (BGP) Autonomous System Number (ASN)."
  default     = "65000"
}

variable "static_ip_prefix" {
  description = "List of IP prefixes used to create static routes to the customer gateway"
  type        = "list"
}

variable "name" {
  description = "vpn connection name"
  default     = "main"
}
