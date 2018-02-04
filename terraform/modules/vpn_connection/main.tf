resource "aws_customer_gateway" "customer_gateway" {
  bgp_asn    = "${var.bgp_asn}"
  ip_address = "${var.customer_gateway_address}"
  type       = "ipsec.1"
  count      = "${var.create_vpn_connection}"

  tags {
    Name = "tf-${var.name}_CG"
  }
}

resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = "${var.vpn_gateway_id}"
  customer_gateway_id = "${aws_customer_gateway.customer_gateway.id}"
  type                = "ipsec.1"
  static_routes_only  = true
  count               = "${var.create_vpn_connection}"

  tags {
    Name = "tf-${var.name}_VPN"
  }
}

resource "aws_vpn_connection_route" "main" {
  destination_cidr_block = "${var.static_ip_prefix[count.index]}"
  vpn_connection_id      = "${element(aws_vpn_connection.main.*.id, count.index)}"
  count                  = "${length(var.static_ip_prefix) * var.create_vpn_connection}"
}
