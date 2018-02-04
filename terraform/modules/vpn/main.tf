resource "aws_vpn_gateway" "vpn_gateway" {
  vpc_id = "${var.vpc_id}"

  tags {
    Name = "tf-${var.name}_VPG"
  }
}
