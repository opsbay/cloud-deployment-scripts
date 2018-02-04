#!/usr/bin/env bash

BASEDIR="/vagrant/codedeploy/on-premise"

#shellcheck disable=SC1090
. "$BASEDIR/common.sh"

Out.blue "Running: ${BASH_SOURCE[0]}"

set +e
#shellcheck disable=SC2154
existing_user=$(aws iam get-user  \
    --user-name "$username" \
    --output text)
set -e

if [[ -n "$existing_user" ]]; then
    # User exists, let's get rid of every single trace of him!
    Out.blue "The user $username is being removed..."

    # Get access key
    access_key=$(aws iam list-access-keys \
        --user-name "$username" \
        --query 'AccessKeyMetadata[0].[AccessKeyId]' \
        --output text)
    if [[ "$access_key" != "None" ]]; then
        # Use access key from above here to delete the access key
        aws iam delete-access-key \
            --user-name "$username" \
            --access-key-id "$access_key"
    fi

    # Get the users policies
    policy_name=$(aws iam list-user-policies \
        --user-name "$username" \
        --query 'PolicyNames[0]' \
        --output text)

    if [[ "$policy_name" != "None" ]]; then
        # Use the policy name taken from above to delete the policy
        aws iam delete-user-policy \
            --user-name "$username" \
            --policy-name "$policy_name"
    fi

    # Delete the user
    aws iam delete-user --user-name "$username"
else
    Out.blue "SKIPPING: The user $username doesn't exist."
fi
