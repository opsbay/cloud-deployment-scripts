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

if [[ "$(get_webserver)" == "httpd" ]]; then
    #Copy apache common config, clean anything that shouldn't be there
    rsync -av --delete "/opt/$APP_NAME/codedeploy/common/httpd/conf/" /etc/httpd/conf/
    rsync -av --delete "/opt/$APP_NAME/codedeploy/common/httpd/conf.d/" /etc/httpd/conf.d/
    
    #Copy environment specific apache config
    env_specific_httpd_conf_dir="/opt/$APP_NAME/codedeploy/$environment/httpd/"
    if [ -d "$env_specific_httpd_conf_dir" ]; then
        rsync -av "$env_specific_httpd_conf_dir" /etc/httpd/
    fi
fi

#Copy php common config
if [ -d "/opt/$APP_NAME/codedeploy/common/php/php.d/" ]; then
    rsync -av "/opt/$APP_NAME/codedeploy/common/php/php.d/" /etc/php.d/
fi
#Copy environment specific php config
env_specific_php_conf_dir="/opt/$APP_NAME/codedeploy/$environment/php/php.d/"
if [ -d "$env_specific_php_conf_dir" ]; then
    rsync -av "$env_specific_php_conf_dir" /etc/php.d/
fi

# Backward compatible, optional override to succeed parameters.yml.j2
# for PHP 5.6 deployments (or other PHP versions)
# Only need to drop in a parameters.56.yml.j2 where needed, e.g. production to
# not force a proliferation of additional templates during the 5.3 -> 5.6 transition
#
succeed_config_template="parameters.yml.j2"
succeed_config_template_versioned="parameters.$PHP_VERSION.yml.j2"
succeed_config_template_versioned_path="s3://$bucket/$DEPLOYMENT_GROUP_NAME/$APP_NAME/app/$succeed_config_template_versioned"
if aws s3 ls "$succeed_config_template_versioned_path" > /dev/null; then
    succeed_config_template=$succeed_config_template_versioned
fi

# Remove files from previous deployments
rm -rf "$s3_config_dir"
mkdir -p "${s3_config_dir}/"{elasticache,aurora-cluster} "${s3_config_dir}/$APP_NAME"

session_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-s.json"
data_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-d.json"
cluster_endpoint="${s3_config_dir}/aurora-cluster/aurora-cluster-endpoint.json"
naviance_creds="${s3_config_dir}/${environment}/db/naviance.json"
edocs_creds="${s3_config_dir}/${environment}/db/edocs.json"
input_data="${s3_config_dir}/input_data.json"
app_config="${s3_config_dir}/$APP_NAME/$environment"
aurora_config=$(get_config_by_env aurora)
cache_s_config=$(get_config_by_env cache_s)
cache_d_config=$(get_config_by_env cache_d)

mkdir -p "$app_config/app" "$app_config/php"
aws s3 cp "$aurora_config" "$cluster_endpoint"
aws s3 cp "$cache_s_config" "$session_cache_endpoint"
aws s3 cp "$cache_d_config" "$data_cache_endpoint"
aws s3 cp "s3://$bucket/${environment}/db/naviance.json" "$naviance_creds"
aws s3 cp "s3://$bucket/${environment}/db/edocs.json" "$edocs_creds"
aws s3 cp "s3://$bucket/$DEPLOYMENT_GROUP_NAME/$APP_NAME/app/$succeed_config_template"    "$app_config/app/parameters.yml.j2"
aws s3 cp "s3://$bucket/$DEPLOYMENT_GROUP_NAME/$APP_NAME/php/php.$PHP_VERSION.ini.j2"        "$app_config/php"

mkdir -p "$APP_DIR/app/config"

session_cache_count_json=$(mktemp)
session_cache_count=$(jq '.[] | length' "$session_cache_endpoint")
session_cache_count=$((session_cache_count + 1))
cat <<SESSION_CACHE_COUNT > "$session_cache_count_json"
{
    "session_cache_count": "$session_cache_count"
}
SESSION_CACHE_COUNT

emitted_json=$(mktemp)
get_server_name_json > "$emitted_json"

# Combine JSON files for jinja2
# Thanks Stack Overflow https://stackoverflow.com/a/36218044/424301
#shellcheck disable=SC2016
printf '{"php_version": "%s"}\n' "$PHP_VERSION" \
    | cat - "$cluster_endpoint" "$naviance_creds" "$edocs_creds" "$emitted_json"  "$session_cache_endpoint" "$data_cache_endpoint" "$session_cache_count_json" \
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

# Set up Apache configs
create_webserver_config_files

#sync UI resources across al nodes in ASG
time_stamp="$(cat "$APP_CONFIG_DIR"/timestamp.txt)"
find "$APP_DIR"/web/bundles -exec touch -t "$time_stamp" {} +
find "$APP_DIR"/src/main/php/Succeed/HobsonsLabsBundle/Resources/public -exec touch -t "$time_stamp" {} +
find "$APP_DIR"/web/css -exec touch -t "$time_stamp" {} +
find "$APP_DIR"/web/js -exec touch -t "$time_stamp" {} +
