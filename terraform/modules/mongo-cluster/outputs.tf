output "security_group_ids" {
  value = ["${aws_security_group.mongo-cluster-security-group.*.id}"]
}
