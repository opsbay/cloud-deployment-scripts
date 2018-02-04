#!/usr/bin/env bash
# Copy this sample to env.sh and customize it, then source it with:
#
#    source env.sh
#

# Replace this with the AWS profile from the AWS cli you want to use
export AWS_PROFILE=hobsons-navianceprod
export AWS_DEFAULT_PROFILE="$AWS_PROFILE"

# Select your AWS region
export AWS_DEFAULT_REGION=us-east-1
export AWS_REGION="$AWS_DEFAULT_REGION"
# Fill in the AMI IDs for your region. These are for us-east-1.
export AWS_AMI_CENTOS_6=ami-1c221e76
export AWS_AMI_CENTOS_7=ami-6d1c2007
export AWS_AMI_UBUNTU_16_04=ami-f0768de6

# Fill this in with either the default VPC from your AWS region
# or with a VPC and subnet ID that have automatic assignment of
# IPv4 addresses enabled
export PACKER_AWS_VPC_ID=vpc-22cbf844
export PACKER_AWS_SUBNET_ID=subnet-e72437ca
