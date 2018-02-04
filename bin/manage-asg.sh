#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enable to see every shell command
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
ASG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$ASG_DIR/common.sh"

ensure_awscli
ensure_jq

AWS_ACCOUNT=$(get_aws_account_alias)
AWS_ACCOUNT_ID=$(get_aws_account_id)
ASG_VARSFILE="${ASG_DIR}/../terraform/asg-capacities-${AWS_ACCOUNT_ID}.json"

function manage-asg::get-all-asgs() {
  try_with_backoff aws autoscaling \
    describe-auto-scaling-groups \
    --output text \
    --query "AutoScalingGroups[].AutoScalingGroupName"
}

function manage-asg::get-all-tf-asgs() {
  try_with_backoff aws autoscaling \
    describe-auto-scaling-groups \
    --output json \
    --query 'AutoScalingGroups[*].{name:AutoScalingGroupName, desired:DesiredCapacity, min:MinSize, max:MaxSize}' \
    | jq -r '.[] | select(.name | startswith("tf-"))'
}

function manage-asg::get-min() {
  local asg_name="${1:?}"
  try_with_backoff aws autoscaling \
    describe-auto-scaling-groups \
    --output text \
    --auto-scaling-group-name "$asg_name" \
    --query "AutoScalingGroups[0].MinSize" \
    2> /dev/null
}

function manage-asg::set-min() {
  local asg_name="${1:?}"
  local min_size="${2:?}"
  try_with_backoff aws autoscaling \
    update-auto-scaling-group \
    --auto-scaling-group-name "$asg_name" \
    --min-size "$min_size"
}

function manage-asg::get-max() {
  local asg_name="${1:?}"
  try_with_backoff aws autoscaling \
    describe-auto-scaling-groups \
    --output text \
    --auto-scaling-group-name "$asg_name" \
    --query "AutoScalingGroups[0].MaxSize" \
    2> /dev/null
}

function manage-asg::set-max() {
  local asg_name="${1:?}"
  local max_size="${2:?}"
  try_with_backoff aws autoscaling \
    update-auto-scaling-group \
    --auto-scaling-group-name "$asg_name" \
    --max-size "$max_size"
}

function manage-asg::get-desired() {
  local asg_name="${1:?}"
  try_with_backoff aws autoscaling \
    describe-auto-scaling-groups \
    --output text \
    --auto-scaling-group-name "$asg_name" \
    --query "AutoScalingGroups[0].DesiredCapacity" \
    2> /dev/null
}

function manage-asg::set-desired() {
  local asg_name="${1:?}"
  local desired_capacity="${2:?}"
  try_with_backoff aws autoscaling \
    update-auto-scaling-group \
    --auto-scaling-group-name "$asg_name" \
    --desired-capacity "$desired_capacity"
}

function manage-asg::get-instance-list () {
  local asg_name="${1:?}"
  try_with_backoff aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${asg_name}" \
    --output text \
    --query "AutoScalingGroups[*].Instances[*].InstanceId[]" \
    2> /dev/null
}

function manage-asg::remove-scale-in-protection-to-instance () {
  local asg_name="${1:?}"
  local instance_id="${2:?}"
  try_with_backoff aws autoscaling set-instance-protection \
    --instance-ids "${instance_id}" \
    --auto-scaling-group-name "${asg_name}" \
    --no-protected-from-scale-in
    2> /dev/null
}

function manage-asg::get-policies () {
  local asg_name="${1:?}"
  try_with_backoff aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${asg_name}" \
    --query "AutoScalingGroups[*].TerminationPolicies[]" \
    2> /dev/null
}

function manage-asg::generate-tfvars() {
  # This will dynamically poll and generate a tfvars file
  # to get the current values of the ASGs.
  echo "Generating ${ASG_VARSFILE} for ${AWS_ACCOUNT}." 

  ASGS=$(manage-asg::get-all-tf-asgs) 

  ASG_JQ=$(echo "$ASGS" | jq -r '{ "\(.name)-min": .min, "\(.name)-max": .max, "\(.name)-desired": .desired }' | jq -s 'add')
  echo "{ \"autoscaling_capacity\": ${ASG_JQ} }" | jq -r . > "${ASG_VARSFILE}"
}

function manage-asg::main() { 
  case $1 in
    rotate)
      echo "FATAL: Not yet implemented"
      #manage-asg::rotate "${@:2}"
    ;;
    generate-tfvars)
      manage-asg::generate-tfvars
    ;;
    *)
      cat <<-EOF
Usage: manage-asg.sh <command>

Available commands are:
generate-tfvars   Generates the needed tfvars file to associate rules with terraform.
EOF
    ;;
    esac  
}

# See http://docs.aws.amazon.com/autoscaling/latest/userguide/as-suspend-resume-processes.html
# If we do not suspend some of the auto scaling processes when we do our deploys, the
# alarm that scales in the processes can fire and terminate one of the nodes we are trying
# to deploy. 
#
# There might be other weirdness that could happen when we are in the middle
# of a deploy also, so let's cast a wide net here and prohibit everything but basic
# autoscaling behaviors: Launch, Terminate, and AddToLoadBalancer.
# 
# The set of processes listed here now matches the list recommended in:
# http://docs.aws.amazon.com/codedeploy/latest/userguide/integrations-aws-auto-scaling.html
scaling_processes='["ReplaceUnhealthy","AZRebalance","AlarmNotification","ScheduledActions"]'

function manage-asg::suspend-asg-processes () {
    local auto_scaling_group_name
    auto_scaling_group_name=${1:-}
    echo "$auto_scaling_group_name: Suspending autoscaling processes $scaling_processes"
    try_with_backoff aws autoscaling suspend-processes \
        --auto-scaling-group-name "$auto_scaling_group_name" \
        --scaling-processes "$scaling_processes" \
        --output text
}

function manage-asg::resume-asg-processes () {
    local auto_scaling_group_name
    auto_scaling_group_name=${1:-}
    echo "$auto_scaling_group_name: Resuming autoscaling processes $scaling_processes"
    try_with_backoff aws autoscaling resume-processes \
        --auto-scaling-group-name "$auto_scaling_group_name" \
        --scaling-processes "$scaling_processes" \
        --output text
}

function manage-asg::suspend-all-processes () {
  declare -a ALL_TF_ASGS
  ALL_TF_ASGS+=($(manage-asg::get-all-asgs))
  for asg in "${ALL_TF_ASGS[@]}"; do
      manage-asg::suspend-asg-processes "$asg"
  done
}

function manage-asg::resume-all-processes () {
  declare -a ALL_TF_ASGS
  ALL_TF_ASGS+=($(manage-asg::get-all-asgs))
  for asg in "${ALL_TF_ASGS[@]}"; do
      manage-asg::resume-asg-processes "$asg"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # This should only run if we are not being sourced.
  verb="${1:-help}"
  manage-asg::main "$verb" "${@:2}"
fi
