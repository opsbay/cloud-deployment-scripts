resource "aws_route_table" "main" {
  count  = "${length(var.subnets)}"
  vpc_id = "${var.vpc_id}"

  tags {
    Name = "tf-${var.name}-rt-main-${count.index}"
  }

  propagating_vgws = ["${var.propagating_vgws}"]
}

resource "aws_route" "internet_gateway" {
  count                  = "${length(var.subnets) * var.create_internet_gateway_route}"
  route_table_id         = "${element(aws_route_table.main.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${var.internet_gateway_id}"
}

resource "aws_route_table_association" "main" {
  count          = "${length(var.subnets)}"
  subnet_id      = "${var.subnets[count.index]}"
  route_table_id = "${element(aws_route_table.main.*.id, count.index)}"
}

resource "aws_route" "private_nat_gateway_route" {
  count                  = "${length(var.nat_gateway_ids)}"
  route_table_id         = "${element(aws_route_table.main.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${var.nat_gateway_ids[count.index]}"
}
