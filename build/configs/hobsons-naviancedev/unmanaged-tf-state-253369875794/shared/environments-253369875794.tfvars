ec2_ssh_key_name = "unmanaged-naviancedev-20170811"

elasticache_num_cache_nodes = 2
elasticache_num_cache_nodes_perftest = 3

aurora_rds_master_password = "jBjkqeJs1U2l0V9oZAAxjKeFERPgrFwlhuvzpcYk"
aurora_rds_master_password_perftest = "CNgnevS3shCLdz5953epYwtTfO3nYYHBE2vPVYly"

# https://jira.hobsons.com/browse/NAWS-1323
aurora_database_instance_type_perftest = "db.r4.large"

# https://jira.hobsons.com/browse/NAWS-1114
jenkins_security_groups = ["sg-28202157"]