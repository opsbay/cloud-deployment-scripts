#!/usr/bin/env bash

# Stub in variable definitions to quiet shellcheck
role_name=${role_name:-}
username=${username:-}
app_name=${app_name:-}
policy_name=${policy_name:-}
deployment_group=${deployment_group:-}

Out.blue "Running: ${BASH_SOURCE[0]}"

# Check if on-premise config file exists
if [[ ! -f "/etc/codedeploy-agent/conf/codedeploy.onpremises.yml" ]]; then
    Out.red "ERROR: The on-premise config file does not exist at /etc/codedeploy-agent/conf/codedeploy.onpremises.yml"
else
    Out.green "OK: The on-premise config file exists at /etc/codedeploy-agent/conf/codedeploy.onpremises.yml"
fi

# Make sure users keys match those in /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
set +e
check_access_key_id=$(aws iam list-access-keys \
    --user-name "$username" \
    --query 'AccessKeyMetadata[0].[AccessKeyId]' \
    --output text)

check_access_key_user=$(aws iam list-access-keys \
    --user-name "$username" \
    --query 'AccessKeyMetadata[0].[UserName]' \
    --output text)
set -e
if [[ -z "$check_access_key_user" ]]; then
    Out.red "ERROR: Access keys don't exist for the user $username"
else
    Out.green "OK: Access keys exist for the user $username"
fi

set +e
if ! grep -Eqw "$check_access_key_id" /etc/codedeploy-agent/conf/codedeploy.onpremises.yml; then
    Out.red "ERROR: The access key ID is incorrect in /etc/codedeploy-agent/conf/codedeploy.onpremises.yml"
else
    Out.green "OK: The access key ID is correct in /etc/codedeploy-agent/conf/codedeploy.onpremises.yml"
fi
set -e

# Make sure $username matches the access key in the config.
set +e
if ! grep -Eqw "$check_access_key_user" /etc/codedeploy-agent/conf/codedeploy.onpremises.yml; then
    Out.red "ERROR: The user name for the access key does not match $username"
else
    Out.green "OK: The user name for the access key matches $username"
fi
set -e

# Make sure 'AWS_ACCOUNT_ID' doesn't exist in the file below
if [[ ! -f "/tmp/CodeDeploy-OnPrem-Permissions-edited.json" ]]; then
    Out.red "ERROR: The policy file wasn't created via 'sed' at /tmp/CodeDeploy-OnPrem-Permissions-edited.json"
else
    Out.green "OK: The policy file was edited via 'sed' at /tmp/CodeDeploy-OnPrem-Permissions-edited.json"
fi

# Check if variables in policy file was edited.
set +e
if grep -Eqw "AWS_ACCOUNT_ID" "/tmp/CodeDeploy-OnPrem-Permissions-edited.json"; then
    Out.red "ERROR: The policy file /tmp/CodeDeploy-OnPrem-Permissions-edited.json was not edited"
else
    Out.green "OK: The policy file /tmp/CodeDeploy-OnPrem-Permissions-edited.json was edited"
fi
set -e

set +e
# Check if role exists by name
check_role_by_name=$(aws iam get-role \
    --role-name "$role_name" \
    --output text)
set -e
if [[ -z "$check_role_by_name" ]]; then
    Out.red "ERROR: The role $role_name doesn't exist"
else
    Out.green "OK: The role $role_name exists"
fi

# Check if deployment group exists
set +e
check_deployment_group=$(aws deploy get-deployment-group \
    --application-name "$app_name" \
    --deployment-group-name "$deployment_group" \
    --output text)
set -e
if [[ -z "$check_deployment_group" ]]; then
    Out.red "ERROR: The deployment group $deployment_group doesn't exist"
else
    Out.green "OK: The deployment group $deployment_group exists"
fi

# Check if policy is attached to role
set +e
check_attached_policy=$(aws iam get-user-policy \
    --user-name "$username" \
    --policy-name "$policy_name" \
    --output text)
set -e
if [[ -z "$check_attached_policy" ]]; then
    Out.red "ERROR: The policy $policy_name is not attached to the user $username"
else
    Out.green "OK: The policy $policy_name is attached to the user $username"
fi

# Check if port 443 can send outgoing requests.
set +e
if timeout 1 bash -c 'cat < /dev/null > /dev/tcp/google.com/443'; then
    Out.green "OK: Outgoing requests on port 443 are allowed."
else
    Out.red "ERROR: Outgoing requests on port 443 are not allowed."
fi
set -e

# TODO: Check if user ARN in log matches the created user (see vagrant output for created user)
Out.blue "INFO: Here are the last 10 lines of the log file at /var/log/aws/codedeploy-agent/codedeploy-agent.log"
tail /var/log/aws/codedeploy-agent/codedeploy-agent.log
