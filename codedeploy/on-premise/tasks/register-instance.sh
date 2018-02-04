#!/usr/bin/env bash

Out.blue "Running: ${BASH_SOURCE[0]}"

declare user_arn
declare instance_name

#shellcheck disable=SC2154
user_arn=$(aws iam get-user \
    --user-name "$username" \
    --query 'User.Arn' \
    --output text)

set +e
Out.blue "Searching for existing instance $instance_name"
#shellcheck disable=SC2154
existing_instance=$(aws deploy list-on-premises-instances \
    --registration-status Registered \
    --tag-filters "Key=Name,Value=$instance_tag,Type=KEY_AND_VALUE" \
    --query 'instanceNames' \
    --output text)
set -e

if [[ -z "$existing_instance" ]]; then
    # On premise instance is not registered.
    Out.blue "Registering on-premise instance with name $instance_name and tag Name: $instance_tag"
    aws deploy register-on-premises-instance \
        --instance-name "$instance_name" \
        --iam-user-arn "$user_arn"
    aws deploy add-tags-to-on-premises-instances \
        --instance-names "$instance_name" \
        --tags "Key=Name,Value=$instance_tag"
else
    Out.blue "A registered on-premise instance already exists with name $instance_name and tag Name: $instance_tag"
fi
