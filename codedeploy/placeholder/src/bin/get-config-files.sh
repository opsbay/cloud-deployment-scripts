#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Uncomment for enhanced debugging
set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$DIR/common.sh"

# Enable this to debug these scripts
set -x

bucket=$(get_aws_s3_app_config_bucket)

# Remove files from previous deployments
s3_config_dir="$APP_CONFIG_DIR/s3"
rm -rf "$s3_config_dir"
mkdir -p "$s3_config_dir"

DEPLOYMENT_GROUP_NAME=${DEPLOYMENT_GROUP_NAME:-qa}
# Download connection info from S3
#shellcheck disable=SC2086
mkdir -p ${s3_config_dir}/{elasticache,aurora-cluster,$APP_NAME}
cache_s_endpoint="${s3_config_dir}/elasticache/elasticache-s.json"
cache_d_endpoint="${s3_config_dir}/elasticache/elasticache-d.json"
cluster_endpoint="${s3_config_dir}/aurora-cluster/aurora-cluster-endpoint.json"
naviance_creds="${s3_config_dir}/${DEPLOYMENT_GROUP_NAME}/db/naviance.json"
edocs_creds="${s3_config_dir}/${DEPLOYMENT_GROUP_NAME}/db/edocs.json"
input_data="${s3_config_dir}/input_data.json"
app_config="${s3_config_dir}/$APP_NAME/$DEPLOYMENT_GROUP_NAME"
aurora_config=$(get_config_by_env aurora)
cache_s_config=$(get_config_by_env cache_s)
cache_d_config=$(get_config_by_env cache_d)

aws s3 cp "$aurora_config" "$cluster_endpoint"
aws s3 cp "$cache_s_config" "$cache_s_endpoint"
aws s3 cp "$cache_d_config" "$cache_d_endpoint"
aws s3 cp "s3://$bucket/${DEPLOYMENT_GROUP_NAME}/db/naviance.json" "$naviance_creds"
aws s3 cp "s3://$bucket/${DEPLOYMENT_GROUP_NAME}/db/edocs.json" "$edocs_creds"
aws s3 cp "s3://$bucket/${DEPLOYMENT_GROUP_NAME}/$APP_NAME/parameters.yml.j2" "$app_config/"

mkdir -p "$APP_DIR/app/config"

# Combine JSON files for jinja2
# Thanks Stack Overflow https://stackoverflow.com/a/36218044/424301
#shellcheck disable=SC2016
cat "$cluster_endpoint" "$cache_d_endpoint" "$cache_s_endpoint" "$naviance_creds" "$edocs_creds" \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
    > "$input_data"

jinja2 \
    "$app_config/parameters.yml.j2" \
    "$input_data" \
    --format=json \
    > "$APP_DIR/app/config/parameters.yml"

create_webserver_config_files
