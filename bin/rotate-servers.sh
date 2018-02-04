#!/usr/bin/env bash
#
# rotate-servers.sh
#
# Rotates AWS Auto Scaling Groups (ASGs)
#
# Specify either the name of an ASG to rotate, or an
# expression with a trailing "*" wildcard glob.
#
# Syntax:
#
#     rotate-servers.sh [(ASG-name|ASG-pattern*)]
#
# Examples:
#
#   # Print the list of ASGs
#   bin/rotate-servers.sh
#
#   # Rotate only the tf-baz-qa Auto Scaling Group
#   bin/rotate-servers.sh tf-baz-qa
#
#   # Rotate all the Auto Scaling group servers
#   # whose names start with tf-foobar
#   bin/rotate-servers.sh tf-foobar*
#
#   # Rotate all the AutoScaling group servers
#   # whose names start with tf*
#   bin/rotate-servers.sh tf*

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
source "$DIR/common.sh"

#shellcheck disable=SC1090
source "$DIR/manage-asg.sh"


asg_expression=${1:-}

function rotate () {
    local asg=${1:-}
    local max_size
    local desired_cap
    local new_desired_cap
    local new_max_size
    local policies
    local restore_policy_result
    local result
    local instance
    local instances
    local instance_array
    result=0
    set +e
    max_size=$(
      aws \
        autoscaling \
        describe-auto-scaling-groups \
        --auto-scaling-group-name "$asg" \
        --query "AutoScalingGroups[0].MaxSize" \
        2> /dev/null
    )

    desired_cap=$(
      aws \
        autoscaling \
        describe-auto-scaling-groups \
        --auto-scaling-group-name "$asg" \
        --query 'AutoScalingGroups[0].DesiredCapacity' \
        --output text \
        2> /dev/null
    )
    set -e

    new_desired_cap=$((desired_cap * 2))
    new_max_size=$(( max_size < new_desired_cap + 1 ? new_desired_cap + 1 : max_size ))

    echo "$asg: Rotating servers - current capacity: $desired_cap, max size: $max_size"
    echo "$asg: Increasing desired capacity from $desired_cap to $new_desired_cap."
    echo "$asg: Max size possibly adjusted from $max_size to $new_max_size."

    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name "$asg" \
      --max-size "$new_max_size" \
      --new-instances-protected-from-scale-in \
      --desired-capacity "$new_desired_cap"

    echo "$asg: Waiting for $((new_desired_cap - desired_cap)) new instance(s) to come online..."
    waited=0
    max_wait_minutes=30
    max_wait=$(( max_wait_minutes * 60 ))
    err=""
    while [[ $(num_in_service "$asg") -lt "$new_desired_cap" ]]; do
        # We will hit the API rate limiter if we are doing this in parallel
        # with a large number of auto scaling groups,
        # so let's back off a bit and spread the requests around
        local rand
        rand=$(perl -e 'print int(rand(30)) + 1')
        sleep "$rand"
        waited=$((waited + rand))
        if [[ $waited -gt $max_wait ]]; then
            err="$asg: ERROR: waited more than $max_wait_minutes minutes. Forcing scale in."
            result=1
            break;
        fi
        echo "$asg: waited $waited seconds for instances to be in service..."
    done

    if [[ -z "$err" ]]; then
        echo "$asg: $new_desired_cap instance(s) are now online"
    fi

    echo "$asg: Recover the termination policies:"
    policies="$(manage-asg::get-policies "$asg" | jq -c '')"

    restore_policy_result=$?
    if [ $restore_policy_result -gt 0 ] ; then
        err="$asg: ERROR: Couldn't recover the termination policies.";
        return 1;
    else
        echo "$asg: termination policies to restore after scaling in: $policies";
    fi

    echo "$asg: scaling back in to $desired_cap instance(s):"

    aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name "$asg" \
      --max-size "$max_size" \
      --desired-capacity "$desired_cap" \
      --termination-policies "OldestInstance"
    result=$?

    if [ $result -gt 0 ] ; then
        err="$asg: ERROR: Couldn't restore the max-size and desired-capacity. Trying to restore policies now.";
    else
        echo "$asg: Waiting for $((new_desired_cap - desired_cap)) older instance(s) to go offline..."
        waited=0
        max_wait_minutes=30
        max_wait=$(( max_wait_minutes * 60 ))
        err=""
        while [[ $(num_in_service "$asg") -gt "$desired_cap" ]]; do
            # We will hit the API rate limiter if we are doing this in parallel
            # with a large number of auto scaling groups,
            # so let's back off a bit and spread the requests around
            local rand
            rand=$(perl -e 'print int(rand(30)) + 1')
            sleep "$rand"
            waited=$((waited + rand))
            if [[ $waited -gt $max_wait ]]; then
                err="$asg: ERROR: waited more than $max_wait_minutes minutes. Forcing scale in."
                result=1
                break;
            fi
            echo "$asg: waited $waited seconds for instances to be terminated..."
        done
    fi

    echo "$asg: Restoring termination policy:"
    try_with_backoff aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name "$asg" \
      --no-new-instances-protected-from-scale-in \
      --termination-policies "$policies"

    restore_policy_result=$?
    if [ $restore_policy_result -gt 0 ] ; then
        err="$asg: ERROR: Couldn't resotre the termination policies";
        return $restore_policy_result;
    else
        echo "$asg: termination policies restored to $policies";
    fi

    echo "$asg: Removing scale in protection of the instances";
    instances="$(manage-asg::get-instance-list "$asg" | sed 's/[[:blank:]]/,/g')"
    IFS=',' read -ra instance_array <<< "$instances"
    for instance in "${instance_array[@]}" ; do
        echo "$asg: Removing scale in protection to $instance";
        manage-asg::remove-scale-in-protection-to-instance "$asg" "$instance"
    done

    echo "$asg: Done."
    return $result
}

#shellcheck disable=SC2016
function get_asgs () {
    local asg_name="${1:-}"
    #shellcheck disable=SC2049
    if [[ "$asg_name" =~ \*$ ]]; then
        local asg_name_stripped
        asg_name_stripped=$(perl -pe 'chop; chop' <<<"$asg_name")
        matcher=$(printf '?starts_with(AutoScalingGroupName, `%s`)' "$asg_name_stripped")
    else
        matcher=$(printf '?AutoScalingGroupName == `%s`' "$asg_name")
    fi
    aws \
      autoscaling \
      describe-auto-scaling-groups \
      --query "AutoScalingGroups[$matcher].AutoScalingGroupName" \
      --output text
}

# List of packages needed for this script to run
declare packages="jq"

# Ensure required packages are installed
for package in $packages; do
    ensure_installed "$package";
done
ensure_awscli

declare_target
asgs=$(get_asgs "$asg_expression")

if [[ -z "$asgs" ]];then
    echo "ERROR: Auto Scaling Group or Groups \"$asg_expression\" not found. These exist:"
    aws \
      autoscaling \
      describe-auto-scaling-groups \
      --query 'AutoScalingGroups[*].AutoScalingGroupName' \
      --output table
    exit 1
fi

echo "Auto Scaling Groups selected: $asgs"

# Thanks Stack Overflow for the background job loop https://stackoverflow.com/a/26240420/424301
pids=""
RESULT=0

for asg in $asgs; do
    (
        manage-asg::suspend-asg-processes "$asg"
        rotate "$asg"
        manage-asg::resume-asg-processes "$asg"
    ) &
    pids="$pids $!"
done

IFS=$' '
for pid in $pids; do
    #shellcheck disable=SC2086
    wait $pid || let "RESULT=1"
done

if [ "$RESULT" == "1" ]; then
    echo "ERROR: at least one subprocess returned an error"
    exit 1
fi
