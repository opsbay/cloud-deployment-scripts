#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

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

# Download connection info from S3
#shellcheck disable=SC2086
mkdir -p ${s3_config_dir}/{elasticache,aurora-cluster}

session_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-s.json"
data_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-d.json"
cluster_endpoint="${s3_config_dir}/aurora-cluster/aurora-cluster-endpoint.json"
naviance_creds="${s3_config_dir}/${DEPLOYMENT_GROUP_NAME}/db/naviance.json"
input_data="${s3_config_dir}/input_data.json"

aurora_config=$(get_config_by_env aurora)
cache_s_config=$(get_config_by_env cache_s)
cache_d_config=$(get_config_by_env cache_d)

aws s3 cp "$aurora_config" "$cluster_endpoint"
aws s3 cp "$cache_s_config" "$session_cache_endpoint"
aws s3 cp "$cache_d_config" "$data_cache_endpoint"
aws s3 cp "s3://$bucket/${DEPLOYMENT_GROUP_NAME}/db/naviance.json" "$naviance_creds"

# Combine JSON files for jinja2
# Thanks Stack Overflow https://stackoverflow.com/a/36218044/424301
#shellcheck disable=SC2016
cat "$cluster_endpoint" "$session_cache_endpoint" "$data_cache_endpoint" "$naviance_creds" \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
    > "$input_data"

# Download app config files from s3
aws s3 cp "s3://$bucket/$DEPLOYMENT_GROUP_NAME/$APP_NAME/codedeploy.yml.j2" "$s3_config_dir"
jinja2 "$s3_config_dir/codedeploy.yml.j2" "$input_data" --format=json > "$APP_CONFIG_DIR/codedeploy.yml"
