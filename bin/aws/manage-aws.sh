#!/usr/bin/env bash
#
# manage-aws.sh
#
# Basic AWS related functions
# Intended to be included from both bin/common.sh and codedeploy common.sh files
#
# We try to structure these includes with manage_aws::get_function_name
# but these functions are called from so many places that we should do a second
# wave of refactoring to globally search and replace where they are used instead
# of making that change at once.

get_aws_region() {
    local aws_region

    if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
        aws_region="$AWS_DEFAULT_REGION"
    elif read -r region < <(aws configure get default.region); then
        aws_region="$region"
    else
        # Thanks Stack Overflow http://stackoverflow.com/a/9263531/424301
        local identity_doc="http://169.254.169.254/latest/dynamic/instance-identity/document"
        aws_region=$(curl \
            -s \
            "$identity_doc" | awk -F\" '/region/ {print $4}')
    fi

    if [[ -z "$aws_region" ]]; then
        echo 'ERROR: The AWS region could not be acquired.' 1>&2
        return 1
    fi

    echo "$aws_region"
}

get_aws_account_alias() {
    aws iam list-account-aliases \
        --query 'AccountAliases' \
        --output text
}

get_aws_account_id() {
    local account_id

    # Thanks Stack Overflow https://stackoverflow.com/a/40121084/424301
    account_id=$(aws sts get-caller-identity \
        --output text \
        --query 'Account' \
        --region "$(get_aws_region)")

    if [[ -z "$account_id" ]]; then
        account_id=$(curl \
            -s \
            http://169.254.169.254/latest/dynamic/instance-identity/document \
            | awk -F '"' '/accountId/ { print $4 }')
    fi

    if [[ -z "$account_id" ]]; then
        echo 'ERROR: The AWS account ID could not be acquired.' 1>&2
        return 1
    fi

    echo "$account_id"
}

# If your script is going to use this function and your build
# process copies manage-aws.sh into a build directory, be sure
# to also copy the get_config.py helper script into the same
# directory.

get_aws_account_user() {
    local user
    # Determine if we are using a role, and set credentials appropriately.
    caller_ident=$(aws sts get-caller-identity --query "Arn" --output text)

    if [[ ${caller_ident} =~ ^arn:aws:sts::[0-9]+:assumed-role ]]; then
        # If we are using an assumed role, we're going to get the user name associated
        # with the source_profile.
        profile=$("${DIR}/get_config.py" "${HOME}/.aws/config" "profile ${AWS_PROFILE}"       source_profile)
        if [[ -z "$profile" ]]; then
            profile=$("${DIR}/get_config.py" "${HOME}/.aws/credentials" "profile              ${AWS_PROFILE}" source_profile)
        fi
        user=$(aws iam get-user --query "User.UserName" --output text --profile "$profile")
    else
        user=$(aws iam get-user --query "User.UserName" --output text)
    fi

    echo "$user"
}

get_aws_instance_id() {
    local instance_id
    instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

    if [[ -z "$instance_id" ]]; then
        echo 'ERROR: The AWS instance ID could not be acquired.' 1>&2
        return 1
    fi

    echo "$instance_id"
}

get_aws_auto_scaling_group_name() {
    local auto_scaling_group_name
    # Thanks Stack Overflow https://serverfault.com/a/654856
    auto_scaling_group_name=$(aws autoscaling \
        describe-auto-scaling-instances \
        --region "$(get_aws_region)" \
        --instance-ids="$(get_aws_instance_id)" \
        --query 'AutoScalingInstances[0].AutoScalingGroupName' \
        --output text)

    if [[ -z "$auto_scaling_group_name" ]]; then
        echo 'ERROR: The AWS Auto Scaling Group name could not be acquired.' 1>&2
        return 1
    fi

    echo "$auto_scaling_group_name"
}

get_aws_auto_scaling_lifecycle_state () {
    local auto_scaling_lifecycle_stage
    # Thanks Stack Overflow https://serverfault.com/a/654856
    auto_scaling_lifecycle_stage=$(aws autoscaling \
        describe-auto-scaling-instances \
        --region "$(get_aws_region)" \
        --instance-ids="$(get_aws_instance_id)" \
        --query 'AutoScalingInstances[0].LifecycleState' \
        --output text)

    if [[ -z "$auto_scaling_lifecycle_stage" ]]; then
        echo 'ERROR: The AWS Auto Scaling Group Lifecycle State could not be acquired.' 1>&2
        return 1
    fi

    echo "$auto_scaling_lifecycle_stage"
}


get_aws_asg_codedeploy_lifecycle_hook() {
    local lifecycle_hook_name
    #shellcheck disable=SC2016
    lifecycle_hook_name=$(aws autoscaling \
        describe-lifecycle-hooks \
        --region "$(get_aws_region)" \
        --auto-scaling-group-name "$(get_aws_auto_scaling_group_name)" \
        --query 'LifecycleHooks[?starts_with(LifecycleHookName, `CodeDeploy-managed-automatic-launch-deployment-hook`) == `true`] | [0].LifecycleHookName' \
        --output text)

    if [[ -z "$lifecycle_hook_name" ]]; then
        echo 'ERROR: The AWS Auto Scaling Group Lifecycle Hook ID for CodeDeploy could not be acquired.' 1>&2
        return 1
    fi

    echo "$lifecycle_hook_name"
}

aws_asg_codedeploy_record_heartbeat() {
    local asg_hook
    local asg_name
    local instance_id
    local lifecycle_state
    local lifecycle_state_desired
    lifecycle_state_desired="Pending:Wait"
    lifecycle_state="$(get_aws_auto_scaling_lifecycle_state)"
    asg_name=$(get_aws_auto_scaling_group_name)
    if [[ "$lifecycle_state" = "$lifecycle_state_desired" ]]; then
        asg_hook=$(get_aws_asg_codedeploy_lifecycle_hook)
        instance_id=$(get_aws_instance_id)
        echo "Recording heartbeat for CodeDeploy for $asg_name on $asg_hook from $instance_id"
        aws autoscaling record-lifecycle-action-heartbeat \
            --region "$(get_aws_region)" \
            --lifecycle-hook-name "$asg_hook" \
            --auto-scaling-group-name "$asg_name" \
            --instance-id "$instance_id" \
            && echo "OK: CodeDeploy heartbeat recorded for $asg_name on $asg_hook from $instance_id"
    else
        echo "Skipping heartbeat: $asg_name is in lifecycle state $lifecycle_state (and not $lifecycle_state_desired)"
    fi
}

get_aws_s3_app_config_bucket() {
    echo "unmanaged-app-config-$(get_aws_account_id)"
}

