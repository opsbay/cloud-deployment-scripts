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

# Remove files from previous deployments
rm -rf "$s3_config_dir"
mkdir -p "${s3_config_dir}/"{elasticache,aurora-cluster} "${s3_config_dir}/$APP_NAME"

session_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-s.json"
data_cache_endpoint="${s3_config_dir}/elasticache/tf-testapp-p-cache-d.json"
cluster_endpoint="${s3_config_dir}/aurora-cluster/aurora-cluster-endpoint.json"
naviance_creds="${s3_config_dir}/${environment}/db/naviance.json"
edocs_creds="${s3_config_dir}/${environment}/db/edocs.json"
mobile_creds="${s3_config_dir}/${environment}/db/mobile.json"
input_data="${s3_config_dir}/input_data.json"
app_config="${s3_config_dir}/$APP_NAME/$environment"

aurora_config=$(get_config_by_env aurora)
cache_s_config=$(get_config_by_env cache_s)
cache_d_config=$(get_config_by_env cache_d)

mkdir -p "$app_config/app" "$app_config/php/53" "$app_config/php/56"

aws s3 cp "$aurora_config" "$cluster_endpoint"
aws s3 cp "$cache_s_config" "$session_cache_endpoint"
aws s3 cp "$cache_d_config" "$data_cache_endpoint"

aws s3 cp "s3://$bucket/${environment}/db/naviance.json"                       "$naviance_creds"
aws s3 cp "s3://$bucket/${environment}/db/edocs.json"                          "$edocs_creds"
aws s3 cp "s3://$bucket/${environment}/db/mobile.json"                         "$mobile_creds"
# the list below was a single sync, avoided to be able to remove the relevant s3 permission.
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/app/config.xml.j2"        "$app_config/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/app/crmConfig.php"        "$app_config/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/app/dbConfig.php.j2"      "$app_config/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/app/mapquestConfig.php"   "$app_config/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/app/salesforceConfig.php" "$app_config/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/app/wk12Config.php"       "$app_config/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/app/wk12Config.php.j2"    "$app_config/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/php/53/apc.ini"           "$app_config/php/53"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/php/53/memcache.ini"      "$app_config/php/53"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/php/53/php.ini.j2"        "$app_config/php/53"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/php/56/php.ini.j2"        "$app_config/php/56"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/php/php.ini.j2"           "$app_config/php"

mkdir -p "${APP_DIR}/config/"
mv "$app_config/app/"{mapquestConfig,salesforceConfig,crmConfig}.php "${APP_DIR}/config/"
mkdir -p "${APP_DIR}/core/config"

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

#shellcheck disable=SC2016
printf '{"php_version": "%s"}\n' "$PHP_VERSION" \
    | cat - "$cluster_endpoint" "$naviance_creds" "$edocs_creds" "$emitted_json" "$mobile_creds" "$session_cache_endpoint" "$data_cache_endpoint" "$session_cache_count_json" \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
    > "$input_data"

jinja2 \
    "$app_config/app/config.xml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/core/config/config.xml"

jinja2 \
    "$app_config/app/dbConfig.php.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/config/dbConfig.php"

jinja2 \
    "$app_config/php/$PHP_VERSION/php.ini.j2" \
    "$input_data" \
    --format=json \
    > /etc/php.ini

jinja2 \
    "$app_config/app/wk12Config.php.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/config/wk12Config.php"

create_webserver_config_files

SOURCE_NGINX_LOG_FORMAT="${APP_CONFIG_DIR}/hobsons-log-format.conf"
DEST_NGINX_LOG_FORMAT="/etc/nginx/hobsons-log-format.conf"
if [[ -f "$SOURCE_NGINX_LOG_FORMAT" ]]; then
    rm -f "$DEST_NGINX_LOG_FORMAT"
    ln -s "$SOURCE_NGINX_LOG_FORMAT" "$DEST_NGINX_LOG_FORMAT"
fi
