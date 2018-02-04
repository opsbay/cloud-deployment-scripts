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

# Backward compatible, optional override to succeed parameters.yml.j2
# for PHP 5.6 deployments (or other PHP versions)
# Only need to drop in a parameters.56.yml.j2 where needed, e.g. production to
# not force a proliferation of additional templates during the 5.3 -> 5.6 transition
#
succeed_config_template="parameters.yml.j2"
succeed_config_template_versioned="parameters.$PHP_VERSION.yml.j2"
succeed_config_template_versioned_path="s3://$bucket/$DEPLOYMENT_GROUP_NAME/succeed/app/$succeed_config_template_versioned"
if aws s3 ls "$succeed_config_template_versioned_path" > /dev/null; then
    succeed_config_template=$succeed_config_template_versioned
fi

# Remove files from previous deployments
s3_config_dir="$APP_CONFIG_DIR/s3"
rm -rf "$s3_config_dir"
mkdir -p "$s3_config_dir"

# Download connection info from S3
#shellcheck disable=SC2086
mkdir -p ${s3_config_dir}/{elasticache,aurora-cluster,$APP_NAME}
session_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-s.json"
data_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-d.json"
cluster_endpoint="${s3_config_dir}/aurora-cluster/aurora-cluster-endpoint.json"
naviance_creds="${s3_config_dir}/${DEPLOYMENT_GROUP_NAME}/db/naviance.json"
edocs_creds="${s3_config_dir}/${DEPLOYMENT_GROUP_NAME}/db/edocs.json"
input_data="${s3_config_dir}/input_data.json"
app_config="${s3_config_dir}/$APP_NAME/$DEPLOYMENT_GROUP_NAME"
aurora_config=$(get_config_by_env aurora)
cache_s_config=$(get_config_by_env cache_s)
cache_d_config=$(get_config_by_env cache_d)

aws s3 cp "$aurora_config" "$cluster_endpoint"
aws s3 cp "$cache_s_config" "$session_cache_endpoint"
aws s3 cp "$cache_d_config" "$data_cache_endpoint"
aws s3 cp "s3://$bucket/${DEPLOYMENT_GROUP_NAME}/db/naviance.json" "$naviance_creds"
aws s3 cp "s3://$bucket/${DEPLOYMENT_GROUP_NAME}/db/edocs.json" "$edocs_creds"
aws s3 cp "s3://$bucket/$DEPLOYMENT_GROUP_NAME/succeed/app/$succeed_config_template" "$app_config/app/parameters.yml.j2"
aws s3 cp "s3://$bucket/$DEPLOYMENT_GROUP_NAME/succeed/php/php.53.ini.j2" "$app_config/php/php.53.ini.j2"
aws s3 cp "s3://$bucket/$DEPLOYMENT_GROUP_NAME/succeed/php/php.56.ini.j2" "$app_config/php/php.56.ini.j2"

for user in apache etl; do
    #shellcheck disable=SC2153
    aws s3 cp "s3://$bucket/$DEPLOYMENT_GROUP_NAME/${APP_CONFIG}/cron-$user.txt" "$app_config/"
done

mkdir -p "$APP_DIR/app/config"

# Combine JSON files for jinja2
# Thanks Stack Overflow https://stackoverflow.com/a/36218044/424301
#shellcheck disable=SC2016
printf '{"php_version": "%s"}\n' "$PHP_VERSION" \
    | cat - "$cluster_endpoint" "$session_cache_endpoint" "$data_cache_endpoint" "$naviance_creds" "$edocs_creds" \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
    > "$input_data"

jinja2 \
    "$app_config/app/parameters.yml.j2" \
    "$input_data" \
    --format=json \
    > "$APP_DIR/app/config/parameters.yml"
jinja2 \
    "$app_config/php/php.$PHP_VERSION.ini.j2" \
    "$input_data" \
    --format=json \
    > "/etc/php.ini"
