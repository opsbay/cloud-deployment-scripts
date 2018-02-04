#!/usr/bin/env bash

# This script will randomly connect to one of the healthy Instances
# in the autoscaling group. Useful for debugging machines when
# constantly rotating them.

# It assumes you have access to the ssh key used in the terraform config, and
# you have been added to the SSH security group for the instances.

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "${DIR}/common.sh"

ASG_NAME="${1:-""}"

if [[ "${ASG_NAME}" == "" ]];then
  echo "No AutoScaling Group defined, please select one of the following:"
  echo

  declare -a ALL_ASGS
  ALL_ASGS+=( $(aws autoscaling describe-auto-scaling-groups --output text --query "AutoScalingGroups[].AutoScalingGroupName") )
  i=1
  for asg in "${ALL_ASGS[@]}"; do
    echo "$i: $asg"
    let i+=1
  done
  echo
  read -r -p 'Choose an Autoscaling Group (number): ' user_asg_group
  ASG_NAME="${ALL_ASGS[$((user_asg_group - 1))]}"
fi

echo "Selecting a random instance from ${ASG_NAME}"
echo
INSTANCE_ID=$(
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${ASG_NAME}" \
    | jq -r '.AutoScalingGroups[0].Instances | map(select(.LifecycleState | contains("InService"))) | .['"$(bc <<<"$RANDOM % $(num_in_service)")"'].InstanceId'
)

INSTANCE_DATA=$(aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" | jq '.Reservations[0].Instances[0]')
USER_NAME=$(get_aws_account_user)
PRIVATE_DNS=$(echo "${INSTANCE_DATA}" | jq -r '.PrivateDnsName')

echo "INFO: Attempting to copy ssh command to clipboard"
if [[ -x $(command -v xclip) ]]; then
  CLIP="xclip"
elif [[ -x $(command -v pbcopy) ]]; then
  CLIP="pbcopy"
else
  echo "WARN: Can't automatically manipulate the clipboard, please copy the following command:"
  CLIP="sed" #:)
fi

echo ssh -A "${USER_NAME}@${PRIVATE_DNS}" | tr -d '\n' | "$CLIP"

echo "INFO: Connecting to bastion host..."
if [[ $(get_aws_account_alias) == "hobsons-navianceprod" ]];then
  BASTION="bastion.devops-prod.naviance.com"
else
  BASTION="bastion.devops.naviance.com"
fi

ssh -A "${USER_NAME}@${BASTION}"
