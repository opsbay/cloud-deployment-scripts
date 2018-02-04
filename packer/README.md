# Packer Setup

This directory contains the set of scripts and ansible roles to build a CentOS 6, CentOS 7, and Ubuntu 16.04 based AMI of testapp. This is a work in progress still, not production ready yet.

Eventually building of the AMIs will be controlled by Jenkins, but to build the AMIs in this directory locally you will need:

* [ansible](http://docs.ansible.com/ansible/intro_installation.html) >= 2
* [packer](https://www.packer.io/downloads.html) >= 0.12
* [jq](https://stedolan.github.io/jq/) >= 1.5

You will need to have [AWS credentials](https://www.packer.io/docs/builders/amazon.html#specifying-amazon-credentials) with proper permissions to launch EC2 instances. 

To run the Packer image build, simply run the `make` command:

    make

## Targeting a different AWS account

These scripts have support for targeting a different account other than the main AWS account. In order to activate this support, you need to do a couple things:

1. Set an `AWS_DEFAULT_PROFILE` variable or set AWS keys through the environment variables `AWS_SECRET_ACCESS_KEY` and `AWS_ACCESS_KEY_ID`
2. Set the environment variables `PACKER_AWS_SUBNET_ID` and `PACKER_AWS_VPC_ID`. These should be set to a subnet configured to assign a default IPv4 address to EC2 VMs created in it. It will not have an effect on the final AMI, this VPC and subnet are only used for AMI creation.

You can get a list of Subnets and VPCs from this command:

> Note: This is only informative, it does not show the use of these subnets.


```
aws ec2 describe-vpcs \
	--filter Name=state,Values=available \
	| jq -r .Vpcs[].VpcId \
	| xargs -I {} aws ec2 describe-subnets --filter Name=vpc-id,Values={} \
	| jq -r '.Subnets[] | .VpcId + ": " + .SubnetId'
```

You _must_ use a subnet that is configured with an Internet Gateway and that will automatically assign public IPv4 addresses to created instances. For the current AWS VPC, as of 2017-04-02, this is VPC `vpc-XXXXXXXX` _Packer-Only-PublicSubNets-VPC_, and subnet `subnet-YYYYYYYY` _Packer-Public-Subnet-ONLY_.

You can run the `make` process with this command with alternate credentials configured
through the usual AWS CLI mechanisms, using different a different VPC and subnet:

    PACKER_AWS_VPC_ID=vpc-XXXXXXXX PACKER_AWS_SUBNET_ID=subnet-YYYYYYYY make

##  Vagrant Support

There is also a `Vagrantfile` in this directory that can be used for testing the Ansible roles locally. Using this is _much_ faster than creating multiple AMIs and is recommended whenever you need to make a change to the Ansible scripts before you run Packer through `make`. 
