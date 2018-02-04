#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enable to see every shell command
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$DIR/common.sh"

###############################################################################
function deployment::get-deployment-instance-list () {
    local deployment_id="${1:?}"
    try_with_backoff aws deploy \
        list-deployment-instances \
        --deployment-id "$deployment_id" \
        --query 'instancesList[]' \
        --output text
}

function deployment::get-deployment-instance-status () {
    local deployment_id="${1:?}"
    local instance_id="${2:?}"
    try_with_backoff aws deploy \
        get-deployment-instance \
        --deployment-id "$deployment_id" \
        --instance-id "$instance_id" \
        --query 'instanceSummary.status' \
        --output text
}

function deployment::get-deployment-information () {
    local deployment_id="${1:?}"
    try_with_backoff aws deploy get-deployment \
        --deployment-id "$deployment_id" \
        --query 'deploymentInfo.[applicationName,deploymentGroupName,deploymentConfigName]' \
        --output text
}

function deployment::get-deployment-status () {
    local deployment_id="${1:?}"
    try_with_backoff aws deploy \
        get-deployment \
        --deployment-id "$deployment_id" \
        --query 'deploymentInfo.status' \
        --output text
}

function deployment::get-deployment-overview () {
    local deployment_id="${1:?}"
    try_with_backoff aws deploy \
        get-deployment \
        --deployment-id "$deployment_id" \
        --query 'deploymentInfo.[status,deploymentOverview]'
}
###############################################################################

deployment="${1:-}"
url="https://console.aws.amazon.com/codedeploy/home?region=$AWS_DEFAULT_REGION#/deployments/$deployment"

if [[ -z "$deployment" ]]; then
    echo "ERROR: you must specify a CodeDeploy deployment ID"
    exit 1
fi


set +e
if ! status=$(deployment::get-deployment-status "$deployment"); then
    echo "ERROR: no deployment with ID \"$deployment\" exists"
    exit 2
fi
set -e

echo "########## Targeting: $(deployment::get-deployment-information "$deployment")"
echo "########## Deployment started, see:"
echo "$url"
echo ""
progress=""
output=""
while [[ $status != "Succeeded" ]] && [[ $status != "Failed" ]] && [[ $status != "Stopped" ]] ; do
    if [[ -n "$output" ]]; then
        sleep 5
    fi
    progress="${progress}."
    status="$(deployment::get-deployment-status "$deployment")"
    overview="$(deployment::get-deployment-overview "$deployment")"
    # Skip rewinding output if we are running under Jenkins,
    # the hint there is that BUILD_NUMBER will be defined
    if [[ -n "$output" ]] && [[ -z "${BUILD_NUMBER:-}" ]]; then
        rewind "$output"
    fi
    output=$(printf "%s\n%s" "$progress" "$overview")
    echo "$output"
done

echo "########## Deployment done with status \"$status\", see:"
echo "$url"

echo "########## Instance Deployment verification start:"
IFS=$' \t\n' read -ra deployed_instances <<< "$(deployment::get-deployment-instance-list "$deployment" | sed 's/\t/ /')"
successful_instances=0
instance_count=${#deployed_instances[@]}
for instance in "${deployed_instances[@]}" ; do
    set +e
    instance_status="$(deployment::get-deployment-instance-status "$deployment" "$instance")"
    set -e
    [ "$instance_status" == "Succeeded" ] && successful_instances=$((successful_instances + 1))
    echo "Instance $instance finished with status $instance_status:"
    echo "$url/instances/$instance/events"
done
echo "########## Instance Deployment verification end with \"$successful_instances\" successful instances from a total of \"$instance_count\"."
echo "$url"

[[ $status = "Succeeded" ]] && [[ $successful_instances -eq $instance_count ]]
