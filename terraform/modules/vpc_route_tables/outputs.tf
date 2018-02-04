output "route_tables" {
  value = ["${aws_route_table.main.*.id}"]
}
