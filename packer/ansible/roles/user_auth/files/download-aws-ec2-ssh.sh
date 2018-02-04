#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# Removed -e because the curl command will exit with code 7 in vagrant
# This should be revisted later when more time is available
set -uo pipefail
IFS=$'\n\t'

# Figure out what account we're in use hobsons-naviancedev as a default
tempAccountId=`curl -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.accountId'`
accountId=${tempAccountId:-253369875794}
# Figure out what region we're in
region=`curl -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region'`
# Grab the instance id
instanceId=`curl -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.instanceId'`
# Grab the FullName tag for the instance
fullName=`aws ec2 describe-tags --filters Name=resource-id,Values=${instanceId} Name=key,Values=Name --region=us-east-1 --query Tags[].Value --output text`

# If tempAccountId is empty assume this is vagrant
if [ -z "$tempAccountId" ]; then
  vagrant="vagrant-"
else
  vagrant=''
fi

# Set s3bucket name and file location
s3bucket="unmanaged-app-config-${accountId}"
overrides3loc="ssh-auth/${fullName}-aws-ec2-ssh.conf"
defaults3loc="ssh-auth/${vagrant}aws-ec2-ssh.conf"

# Attempt to download ovveride version of aws-ec2-ssh.conf
{ 
  echo 'Attempting to download override aws-ec2-ssh configuration...'
  aws s3 cp s3://${s3bucket}/${overrides3loc} /etc/aws-ec2-ssh.conf 
} || {
  # Fallback to downloading the default aws-ec2-ssh.conf
  echo 'Falling back to default aws-ec2-ssh configuration...'
  aws s3 cp s3://${s3bucket}/${defaults3loc} /etc/aws-ec2-ssh.conf
}