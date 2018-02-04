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
mkdir -p "${s3_config_dir}/${aurora-cluster}" "${s3_config_dir}/$APP_NAME"

session_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-s.json"
cluster_endpoint="${s3_config_dir}/aurora-cluster/aurora-cluster-endpoint.json"
naviance_creds="${s3_config_dir}/${environment}/db/naviance.json"
app_config="${s3_config_dir}/$APP_NAME/$environment"
input_data="${s3_config_dir}/input_data.json"

aurora_config=$(get_config_by_env aurora)
cache_s_config=$(get_config_by_env cache_s)

aws s3 cp "$aurora_config" "$cluster_endpoint"
aws s3 cp "s3://$bucket/${environment}/db/naviance.json" "$naviance_creds"
aws s3 cp "$cache_s_config" "$session_cache_endpoint"

aws s3 cp "s3://$bucket/${environment}/$APP_NAME/db.yml.j2"       "${app_config}/"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/env.yml.j2"      "${app_config}/"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/global.yml.j2"   "${app_config}/"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/php.56.ini.j2"   "${app_config}/"


#shellcheck disable=SC2016
cat "$cluster_endpoint" "$naviance_creds" "$session_cache_endpoint" \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
    > "$input_data"

jinja2 \
    "$app_config/db.yml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/area51/config/db.yml"

jinja2 \
    "$app_config/env.yml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/area51/config/env.yml"

jinja2 \
    "$app_config/global.yml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/area51/config/global.yml"

jinja2 \
    "$app_config/php.${INSTALLED_PHP_VERSION_CODE}.ini.j2" \
    "$input_data" \
    --format=json \
    > /etc/php.ini

create_webserver_config_files

SOURCE_NGINX_LOG_FORMAT="${APP_CONFIG_DIR}/hobsons-log-format.conf"
DEST_NGINX_LOG_FORMAT="/etc/nginx/hobsons-log-format.conf"
if [[ -f "$SOURCE_NGINX_LOG_FORMAT" ]]; then
    rm -f "$DEST_NGINX_LOG_FORMAT"
    ln -s "$SOURCE_NGINX_LOG_FORMAT" "$DEST_NGINX_LOG_FORMAT"
fi
