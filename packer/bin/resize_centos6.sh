#!/usr/bin/env bash

# cloud-utils-growpart is required for cloud-init to be able to expand the partition
sudo yum -y install epel-release
sudo yum -y install cloud-utils-growpart

# Cloud-init doesn't run on boot if anything is in this directory
sudo rm -rf /var/lib/cloud/instances/*

# Reboot as part of provisioning so that we're not expanding the root
# partition for every instance on boot
sudo reboot

# A shell provisioner must follow this one with a "pause_before" statement to
# ensure that packer waits for the instance to reboot before attempting to
# create an AMI
