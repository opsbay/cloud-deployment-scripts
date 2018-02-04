#!/usr/bin/env bash

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

bucket=$(get_aws_s3_app_config_bucket)
s3_config_dir="$APP_CONFIG_DIR/s3"

# See https://aws.amazon.com/blogs/devops/using-codedeploy-environment-variables/
environment=${DEPLOYMENT_GROUP_NAME:-qa}

# Remove files from previous deployments
rm -rf "$s3_config_dir"
mkdir -p "${s3_config_dir}/"{elasticache,aurora-cluster} "${s3_config_dir}/$APP_NAME"

cluster_endpoint="${s3_config_dir}/aurora-cluster/aurora-cluster-endpoint.json"
naviance_creds="${s3_config_dir}/${environment}/db/naviance.json"
input_data="${s3_config_dir}/input_data.json"
app_config="${s3_config_dir}/$APP_NAME/$environment"

mkdir -p "$app_config/application-data-provisioner/" \
    "$app_config/college-core-provisioner/" \
    "$app_config/college-destination-core-provisioner/" \
    "$app_config/school-core-provisioner/" \
    "${APP_DIR}/application-data-provisioner/" \
    "${APP_DIR}/college-core-provisioner/" \
    "${APP_DIR}/college-destination-core-provisioner/" \
    "${APP_DIR}/school-core-provisioner/"

aurora_config=$(get_config_by_env aurora)

aws s3 cp "$aurora_config" "$cluster_endpoint"

aws s3 cp "s3://$bucket/${environment}/db/naviance.json"             "$naviance_creds"
# the list below was a single sync, avoided to be able to remove the relevant s3 permission.
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/application-data-provisioner/application.yml.j2"         "$app_config/application-data-provisioner/"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/college-core-provisioner/application.yml.j2"             "$app_config/college-core-provisioner/"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/college-destination-core-provisioner/application.yml.j2" "$app_config/college-destination-core-provisioner/"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/school-core-provisioner/application.yml.j2"              "$app_config/school-core-provisioner/"

#shellcheck disable=SC2016
cat - "$cluster_endpoint" "$naviance_creds" \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
    > "$input_data"

jinja2 \
    "$app_config/application-data-provisioner/application.yml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/application-data-provisioner/application.yml"

jinja2 \
    "$app_config/college-core-provisioner/application.yml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/college-core-provisioner/application.yml"

jinja2 \
    "$app_config/college-destination-core-provisioner/application.yml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/college-destination-core-provisioner/application.yml"

jinja2 \
    "$app_config/school-core-provisioner/application.yml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/school-core-provisioner/application.yml"
