#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
source "$DIR/common.sh"

AWS_DEFAULT_REGION=$(get_aws_region)
export AWS_DEFAULT_REGION

# Thanks Stack Overflow https://stackoverflow.com/a/40121084/424301
AWS_ACCOUNT_ID=$(get_aws_account_id)
bucket="s3://unmanaged-app-config-${AWS_ACCOUNT_ID}"

# See https://aws.amazon.com/blogs/devops/using-codedeploy-environment-variables/
environment=${DEPLOYMENT_GROUP_NAME:-qa}
APP_CONFIG_DIR="${APP_DIR}"
INPUT_DATA="${APP_CONFIG_DIR}/input_data.json"
AURORA_CONFIG=$(get_config_by_env aurora)
CLUSTER_ENDPOINT="$APP_CONFIG_DIR/aurora-cluster-endpoint.json"

aws s3 cp "$AURORA_CONFIG" "$CLUSTER_ENDPOINT"
aws s3 cp "$bucket/${environment}/db/naviance.json"                 "$APP_CONFIG_DIR"
aws s3 cp "$bucket/${environment}/${APP_NAME}/application-standard.j2" "$APP_CONFIG_DIR"

# Combine JSON files for jinja2
# Thanks Stack Overflow https://stackoverflow.com/a/36218044/424301
#shellcheck disable=SC2016
cd "$APP_CONFIG_DIR" && cat "$CLUSTER_ENDPOINT" "naviance.json"   \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)'                     \
    > "$INPUT_DATA"

jinja2 "$APP_CONFIG_DIR/application-standard.j2" "$INPUT_DATA" --format=json > "$APP_CONFIG_DIR/application-standard.yml"
