#!/usr/bin/env bash

# Retries a command a with backoff.
#
# The retry count is given by ATTEMPTS (default 5), the
# initial backoff timeout is given by TIMEOUT in seconds
# (default 1.)
#
# Successive backoffs double the timeout.
# Beware of set -e killing your whole script!
#
# Thanks to Coderwall
#   --> https://coderwall.com/p/--eiqg/exponential-backoff-in-bash
function try_with_backoff {
    local max_attempts=${ATTEMPTS-6}
    local timeout=${TIMEOUT-1}
    local attempt=0
    local exitCode=0

    while [[ $attempt < $max_attempts ]]
    do
        "$@"
        exitCode=$?

        if [[ $exitCode == 0 ]]
        then
            break
        fi

        echo "Failure! Retrying in $timeout.." 1>&2
        sleep "$timeout"
        attempt=$(( attempt + 1 ))
        timeout=$(( timeout * 2 ))
    done

    if [[ $exitCode != 0 ]]
    then
        #shellcheck disable=SC2145
        echo "You've failed me for the last time! ($@)" 1>&2
    fi

    return $exitCode
}

function get_new_hostname {
    local ACCOUNT_DATA
    local REGION
    local INSTANCE_ID
    local INSTANCE_NAME
    local ASG_NAME
    local NAME

    ACCOUNT_DATA=$(try_with_backoff curl -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document)
    REGION=$(echo "$ACCOUNT_DATA" | awk -F '"' '/region/ { print $4 }')
    INSTANCE_ID=$(echo "$ACCOUNT_DATA" | awk -F '"' '/instanceId/ { print $4 }')
    INSTANCE_NAME=$(try_with_backoff aws ec2 describe-tags --filters Name=resource-id,Values="$INSTANCE_ID" Name=key,Values=Name --region="$REGION" --query Tags[].Value --output text)
    # Thanks to Stack Overflow --> https://stackoverflow.com/questions/18338585/how-to-get-the-instance-name-from-the-instance-in-aws
    #                          --> https://serverfault.com/questions/654791/fetch-autoscaling-group-name-in-aws
    # For recovering it without using tags (Amazon reference)
    #                          --> http://docs.aws.amazon.com/cli/latest/reference/autoscaling/describe-auto-scaling-instances.html#examples
    ASG_NAME=$(try_with_backoff aws autoscaling describe-auto-scaling-instances --region="$REGION" --instance-ids="$INSTANCE_ID" --query AutoScalingInstances[0].AutoScalingGroupName --output=text)

    # Name tag exists on the instance
    if [[ -n "$INSTANCE_NAME" ]]; then
        # Trim off any the "-instance" from the end of the name for the sake of conciseness
        NAME="$(sed -e 's/-instance$//' <<<"$INSTANCE_NAME")-$INSTANCE_ID"
    # Name tag does not exist and instance is in an ASG
    elif [[ -n "$ASG_NAME" ]]; then
        # Trim off any the "-asg" from the end of the auto scaling group name for the sake of conciseness
        NAME="$(sed -e 's/-asg$//' <<<"$ASG_NAME")-$INSTANCE_ID"
    fi

    echo $NAME
}

function update_hostname {
    local hosts
    local network    
    local new_hostname
    
    hosts="/etc/hosts"
    network="/etc/sysconfig/network"    

    old_hostname=$(hostname)
    new_hostname=$(get_new_hostname)
    if [[ -n "$new_hostname" ]]; then
        sed -i.bak -e "
/$old_hostname/d;
\$a\
127.0.0.1   ${new_hostname}" \
            $hosts
        sed -i.bak \
            -e "s/^HOSTNAME=.*/HOSTNAME=${new_hostname}/g" \
            $network
        # Thanks Server Fault https://serverfault.com/a/667230
        if [[ -n "$(which hostnamectl)" ]]; then
            hostnamectl set-hostname "$new_hostname"
        else
            hostname "$new_hostname"
        fi
        echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99_hostname.cfg
        echo "[ OK - Changed hostname from $old_hostname to $new_hostname ]"
    else
        echo "[ Error - Kept old hostname $old_hostname - Could not determine new hostname]"
    fi
}

