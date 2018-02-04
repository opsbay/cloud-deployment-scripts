#!/usr/bin/env bash

INSTANCEID=`aws ec2 run-instances       \
    --image-id ami-73456f65             \
    --subnet-id subnet-5a64da76         \
    --security-group-ids sg-18d57c69 sg-97d27be6 sg-d8d57ca9    \
    --count 1                           \
    --instance-type m4.2xlarge          \
    --key-name testapp                  \
    --query 'Instances[0].InstanceId'   | sed 's/"//g'`

echo $INSTANCEID

aws ec2 create-tags --resources $INSTANCEID --tags "Key=Name,Value=unmanaged-nfs-test"

DNSNAME=`aws ec2 describe-instances --instance-ids $INSTANCEID | jq -r '.Reservations[0].Instances[0].PublicDnsName'`

echo $DNSNAME

