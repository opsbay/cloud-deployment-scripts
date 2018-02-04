#!/usr/bin/env bash

Out.blue "Running: ${BASH_SOURCE[0]}"

DIR="$BASEDIR/tasks"

set +e
# Check if role exists by name
#shellcheck disable=SC2154
created_role_arn=$(aws iam get-role \
    --role-name "$role_name" \
    --query 'Role.Arn' \
    --output text)
set -e
if [[ -z "$created_role_arn" ]]; then
    Out.blue "Creating a role: $role_name"
    created_role_arn=$(aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document "file://$DIR/../CodeDeployDemo-Trust.json" \
      --query 'Role.Arn' --output text)
fi

# Attach policy to role
Out.blue "Attaching policy to role"
aws iam attach-role-policy \
  --role-name "$role_name" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"

set +e
#shellcheck disable=SC2154
existing_application=$(aws deploy get-application \
    --application-name "$app_name" \
    --output text)
set -e
if [[ -z "$existing_application" ]]; then
    Out.blue "Creating application because it doesn't exist."
    aws deploy create-application --application-name "$app_name"
fi

# List deployment groups
set +e
deployment_group=${deployment_group:-onpremise}
#shellcheck disable=SC2016
deployment_groups=$(aws deploy list-deployment-groups \
  --application-name "$app_name" \
  --query "$(printf 'deploymentGroups[?contains(@, `%s`)]' "$deployment_group")" \
  --output text)
set -e

#shellcheck disable=SC2154
deployment_group_regexp="^$deployment_group$"
if [[ ! "$deployment_groups" =~ $deployment_group_regexp ]]; then
    Out.blue "There's no deployment group so we create one: $deployment_group"
  #shellcheck disable=SC2154
    aws deploy create-deployment-group \
      --application-name "$app_name" \
      --deployment-group-name "$deployment_group" \
      --on-premises-instance-tag-filters "Key=Name,Value=$instance_tag,Type=KEY_AND_VALUE" \
      --service-role-arn "$created_role_arn" \
      --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE
else
    Out.blue "A deployment group by the name $deployment_group already exists"
fi
