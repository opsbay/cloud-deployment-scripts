# This needs to be the main or default VPC in the account
corp_vpc_id = "vpc-22cbf844"
# This needs to be the default routing table for the main VPC in the account
corp_rt_id_1 = "rtb-b60b45cf"
# This is for future expansion, this is unused currently
corp_rt_id_2 = "rtb-SSSSSSSS"
# This is needed for VPC peering for Jenkins build to talk to RDS databases in this env
devtools_vpc_id = "vpc-46362720"
devtools_vpc_rt_jenkins_agents = "rtb-09446e70"
