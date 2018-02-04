resource "aws_elasticache_parameter_group" "testapp-parameter-group" {
  name   = "testapp-parameter-group"
  family = "memcached1.4"

  parameter {
    name  = "max_item_size"
    value = 15728640        // 15MB
  }
}

resource "aws_elasticache_cluster" "testapp-private-elasticache-session-instance" {
  cluster_id           = "tf-testapp-p-cache-s"
  engine               = "memcached"
  node_type            = "${var.elasticache_node_type}"
  port                 = 11211
  num_cache_nodes      = "${var.elasticache_num_cache_nodes}"
  parameter_group_name = "${aws_elasticache_parameter_group.testapp-parameter-group.name}"
  subnet_group_name    = "${module.vpc.private_cache_subnet_group}"

  security_group_ids = [
    "${aws_security_group.elasticache-private.id}",
    "${aws_security_group.elasticache-private-from-vpn.id}",
    "${aws_security_group.elasticache-private-from-peer-vpc.id}",
  ]

  apply_immediately = true
}

resource "aws_elasticache_cluster" "testapp-private-elasticache-data-instance" {
  cluster_id           = "tf-testapp-p-cache-d"
  engine               = "memcached"
  node_type            = "${var.elasticache_node_type_perftest}"
  port                 = 11211
  num_cache_nodes      = "${var.elasticache_num_cache_nodes}"
  parameter_group_name = "${aws_elasticache_parameter_group.testapp-parameter-group.name}"
  subnet_group_name    = "${module.vpc.private_cache_subnet_group}"

  security_group_ids = [
    "${aws_security_group.elasticache-private.id}",
    "${aws_security_group.elasticache-private-from-vpn.id}",
    "${aws_security_group.elasticache-private-from-peer-vpc.id}",
  ]

  apply_immediately = true
}

resource "aws_elasticache_parameter_group" "perftest-parameter-group" {
  name   = "perftest-parameter-group"
  family = "memcached1.4"

  parameter {
    name  = "max_item_size"
    value = 15728640        // 15MB
  }
}

resource "aws_elasticache_cluster" "private-elasticache-session-instance-perftest" {
  cluster_id           = "tf-perftest-cache-s"
  engine               = "memcached"
  node_type            = "${var.elasticache_node_type_perftest}"
  port                 = 11211
  num_cache_nodes      = "${var.elasticache_num_cache_nodes_perftest}"
  parameter_group_name = "${aws_elasticache_parameter_group.perftest-parameter-group.name}"
  subnet_group_name    = "${module.vpc.private_cache_subnet_group}"

  security_group_ids = [
    "${aws_security_group.elasticache-private.id}",
    "${aws_security_group.elasticache-private-from-vpn.id}",
    "${aws_security_group.elasticache-private-from-peer-vpc.id}",
  ]

  apply_immediately = true
}

resource "aws_elasticache_cluster" "private-elasticache-data-instance-perftest" {
  cluster_id           = "tf-perftest-cache-d"
  engine               = "memcached"
  node_type            = "${var.elasticache_node_type_perftest}"
  port                 = 11211
  num_cache_nodes      = "${var.elasticache_num_cache_nodes_perftest}"
  parameter_group_name = "${aws_elasticache_parameter_group.perftest-parameter-group.name}"
  subnet_group_name    = "${module.vpc.private_cache_subnet_group}"

  security_group_ids = [
    "${aws_security_group.elasticache-private.id}",
    "${aws_security_group.elasticache-private-from-vpn.id}",
    "${aws_security_group.elasticache-private-from-peer-vpc.id}",
  ]

  apply_immediately = true
}
