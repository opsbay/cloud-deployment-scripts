aws-environment = "hobsons-navianceprod"

environments = [
    "production",
    "preprod"
]

ec2_ssh_key_name = "unmanaged-navianceprod-20170811"

assume_role_for_ssh_auth = true

aurora_environment_name = "production"
aurora_database_instance_type = "db.r4.8xlarge"
aurora_rds_master_username = "root_prod_KXKX0"
aurora_rds_master_password = "KZ4xY9gUaFR3BbpqQiQxamYxpBYT889g"
aurora_database_name = "root_default"
aurora_backup_retention_period = "35"
aurora_cluster_instance_count = "3"

aurora_environment_name_perftest = "preprod"
aurora_database_instance_type_perftest = "db.r4.8xlarge"
aurora_rds_master_username_perftest = "root_preprod_G9"
aurora_rds_master_password_perftest = "GTWU6pEp0w3SZa9906nPBQ5mP9lq5GM6d1jA5j"
aurora_database_name_perftest = "root_default"
aurora_backup_retention_period_perftest = "1"
aurora_cluster_instance_count_perftest = "3"

elasticache_node_type = "cache.m4.large"
elasticache_num_cache_nodes = 3

elasticache_node_type_perftest = "cache.m4.large"
elasticache_num_cache_nodes_perftest = 3

vpc_cidr = "10.88.0.0/16"

vpc_subnets = [
  "10.88.0.0/22",
  "10.88.4.0/22",
  "10.88.8.0/22",
  "10.88.12.0/22",
]

vpc_private_app_subnets = [
  "10.88.16.0/22",
  "10.88.20.0/22",
  "10.88.24.0/22",
  "10.88.28.0/22",
]

vpc_private_rds_subnets = [
  "10.88.32.0/22",
  "10.88.36.0/22",
  "10.88.40.0/22",
  "10.88.44.0/22",
]

vpc_private_cache_subnets = [
  "10.88.48.0/22",
  "10.88.52.0/22",
  "10.88.56.0/22",
  "10.88.60.0/22",
]

datacenter-iad-static_ip_prefix = [
  "10.32.0.0/16",
]

cidr_devtools = [
    "10.200.0.0/20",  # subnet-1548275d | A public
    "10.200.32.0/20", # subnet-a166c8fb | B public
    "10.200.64.0/20", # subnet-471d1422 | C public
]

cidr_bigdata_vpc = [
    "10.74.0.0/16", # 626707481977 BigDataProd vpc
]

# These are the permanent elastic IPs for the NAT gateways, allocated outside of Terraform.
# We had do to it that way in order to get stable addresses.
# See: https://jira.hobsons.com/browse/NAWS-539
nat_gw_eip_allocs = [
    "eipalloc-89fcebb9",
    "eipalloc-29eff819",
    "eipalloc-64e0f754",
    "eipalloc-948a9da4",
]

certificate_id  = {
    # star (in the hobsons-navianceprod account, this should be the *.papaya.naviance.com account)
    star = "arn:aws:acm:us-east-1:989043056009:certificate/9489edd4-0063-45dc-837f-4df87ecf45b4"

    # *.papaya.naviance.com
    hobsons-navianceprod = "arn:aws:acm:us-east-1:989043056009:certificate/9489edd4-0063-45dc-837f-4df87ecf45b4"

    # star_naviance_com (same as *.naviance.com)
    star_naviance_com = "arn:aws:iam::989043056009:server-certificate/cloudfront/star.naviance.com_SHA2_2019"

    # succeed
    succeed-53-production = "arn:aws:iam::989043056009:server-certificate/cloudfront/succeed.naviance.com_SHA2_EV_2018"
    succeed-56-production = "arn:aws:iam::989043056009:server-certificate/cloudfront/succeed.naviance.com_SHA2_EV_2018"

    # activematch *.naviance.com
    activematch-56-production = "arn:aws:acm:us-east-1:989043056009:certificate/e0ac57dc-a142-45f6-afe7-78b9b9c07a2f"

    # crm *.naviance.com
    crm-56-production = "arn:aws:acm:us-east-1:989043056009:certificate/e0ac57dc-a142-45f6-afe7-78b9b9c07a2f"

    # connection
    connection-53-production = "arn:aws:iam::989043056009:server-certificate/cloudfront/connection.naviance.com_SHA2_EV_2018"
    connection-56-production = "arn:aws:iam::989043056009:server-certificate/cloudfront/connection.naviance.com_SHA2_EV_2018"

    # learnapi NAWS-934 *.naviance.com
    learnapi-production = "arn:aws:acm:us-east-1:989043056009:certificate/e0ac57dc-a142-45f6-afe7-78b9b9c07a2f"

    # legacyapi NAWS-66 *.naviance.com
    legacyapi-production = "arn:aws:acm:us-east-1:989043056009:certificate/e0ac57dc-a142-45f6-afe7-78b9b9c07a2f"

    # iambridge NAWS-965 *.naviance.com
    iambridge-production = "arn:aws:acm:us-east-1:989043056009:certificate/e0ac57dc-a142-45f6-afe7-78b9b9c07a2f"

    # servicesapi NAWS-919 *.naviance.com
    servicesapi-53-production = "arn:aws:acm:us-east-1:989043056009:certificate/e0ac57dc-a142-45f6-afe7-78b9b9c07a2f"
    servicesapi-56-production = "arn:aws:acm:us-east-1:989043056009:certificate/e0ac57dc-a142-45f6-afe7-78b9b9c07a2f"
}

# 2017-08-26 We had this temporarily enabled when the normal virtual IP
# of this server in the data center DMZ was not reachable. This is one
# of the individual AD servers. The normal server is 10.32.168.87
#dns_active_directory_iad_address = 10.32.106.8
