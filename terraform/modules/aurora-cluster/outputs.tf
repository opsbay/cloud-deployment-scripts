########################
## Output
########################

output "cluster_address" {
  value = "${aws_rds_cluster.aurora_cluster.endpoint}"
}

output "cluster_port" {
  value = "${aws_rds_cluster.aurora_cluster.port}"
}

output "reader_address" {
  value = "${aws_rds_cluster.aurora_cluster.reader_endpoint}"
}

output "instance_address" {
  value = ["${aws_rds_cluster_instance.aurora_cluster_instance.*.endpoint}"]
}

output "master_username" {
  value = "${var.rds_master_username}"
}

output "master_password" {
  value = "${var.rds_master_password}"
}

output "default_database_name" {
  value = "${var.database_name}"
}
