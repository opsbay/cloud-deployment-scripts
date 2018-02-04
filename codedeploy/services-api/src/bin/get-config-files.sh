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

php_version=$(php --version | head -1 | cut -d\  -f 2 | cut -d\. -f1-2 | sed 's/\.//')

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
FC_APP_NAME="family-connection"

aws s3 cp "$aurora_config" "$cluster_endpoint"
aws s3 cp "$cache_s_config" "$session_cache_endpoint"
aws s3 cp "$cache_d_config" "$data_cache_endpoint"
aws s3 cp "s3://$bucket/${environment}/db/naviance.json" "$naviance_creds"
aws s3 cp "s3://$bucket/${environment}/db/edocs.json" "$edocs_creds"
aws s3 cp "s3://$bucket/${environment}/db/mobile.json" "$mobile_creds"

# create the necessary sub-directories in app_config
mkdir -p "$app_config/assessment-api-prototype/resources/config"
mkdir -p "$app_config/$FC_APP_NAME/app"
mkdir -p "$app_config/$FC_APP_NAME/php/53"
mkdir -p "$app_config/$FC_APP_NAME/php/56"
mkdir -p "$app_config/legacy-nav-api-v1/application/config"
mkdir -p "$app_config/legacy-nav-api-v1/core/config"
mkdir -p "$app_config/legacy-nav-api-v2/application/config"
mkdir -p "$app_config/legacy-nav-api-v2/application/config"
mkdir -p "$app_config/legacy-naviance-student-mobile-api/application/config"
mkdir -p "$app_config/legacy-naviance-student-mobile-api/core/config"
mkdir -p "$app_config/naviance-auth-bridge/app/config"
mkdir -p "$app_config/naviance-student-college-bridge/app/config"

# that was previously done by a single sync but now we copy file by file:
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/assessment-api-prototype/resources/config/services.json.dist.j2"       "$app_config/assessment-api-prototype/resources/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/app/config.xml.j2"                                       "$app_config/$FC_APP_NAME/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/app/crmConfig.php"                                       "$app_config/$FC_APP_NAME/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/app/dbConfig.php.j2"                                     "$app_config/$FC_APP_NAME/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/app/mapquestConfig.php"                                  "$app_config/$FC_APP_NAME/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/app/salesforceConfig.php"                                "$app_config/$FC_APP_NAME/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/app/wk12Config.php.j2"                                   "$app_config/$FC_APP_NAME/app"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/php/53/php.ini.j2"                                       "$app_config/$FC_APP_NAME/php/53"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/php/56/php.ini.j2"                                       "$app_config/$FC_APP_NAME/php/56"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/$FC_APP_NAME/php/apc.ini"                                             "$app_config/$FC_APP_NAME/php"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/legacy-nav-api-v1/application/config/application.ini"                  "$app_config/legacy-nav-api-v1/application/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/legacy-nav-api-v1/core/config/config.xml.j2"                           "$app_config/legacy-nav-api-v1/core/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/legacy-nav-api-v2/application/config/application.ini"                  "$app_config/legacy-nav-api-v2/application/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/legacy-nav-api-v2/application/config/config.xml.j2"                    "$app_config/legacy-nav-api-v2/application/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/legacy-naviance-student-mobile-api/application/config/application.ini" "$app_config/legacy-naviance-student-mobile-api/application/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/legacy-naviance-student-mobile-api/core/config/config.xml.j2"          "$app_config/legacy-naviance-student-mobile-api/core/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/naviance-auth-bridge/app/config/parameters.yml.j2"                     "$app_config/naviance-auth-bridge/app/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/naviance-student-college-bridge/app/config/parameters.yml.j2"          "$app_config/naviance-student-college-bridge/app/config"
aws s3 cp "s3://$bucket/${environment}/$APP_NAME/parameters.yml.j2"                                                     "$app_config"

session_cache_count_json=$(mktemp)
session_cache_count=$(jq '.[] | length' "$session_cache_endpoint")
session_cache_count=$((session_cache_count + 1))
cat <<SESSION_CACHE_COUNT > "$session_cache_count_json"
{
    "session_cache_count": "$session_cache_count"
}
SESSION_CACHE_COUNT

mkdir -p "${APP_DIR}/k12/core/config"
#shellcheck disable=SC2016
cat "$cluster_endpoint" "$naviance_creds" "$edocs_creds" "$mobile_creds" "$session_cache_endpoint" "$data_cache_endpoint" "$session_cache_count_json" \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
    > "$input_data"

# familyconect (succeed legacy) configs
mkdir -p "${APP_DIR}/k12/config/"
mv "$app_config/$FC_APP_NAME/app/"{mapquestConfig,salesforceConfig,crmConfig}.php "${APP_DIR}/k12/config/"
jinja2 \
    "$app_config/$FC_APP_NAME/app/config.xml.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/k12/core/config/config.xml"

jinja2 \
    "$app_config/$FC_APP_NAME/app/dbConfig.php.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/k12/config/dbConfig.php"

jinja2 \
    "$app_config/$FC_APP_NAME/php/$php_version/php.ini.j2" \
    "$input_data" \
    --format=json \
    > /etc/php.ini

if [[ "$php_version" == "53" ]] ; then
    cp "$app_config/$FC_APP_NAME/php/apc.ini" /etc/php.d/
fi

jinja2 \
    "$app_config/$FC_APP_NAME/app/wk12Config.php.j2" \
    "$input_data" \
    --format=json \
    > "${APP_DIR}/k12/config/wk12Config.php"

# naviance-auth-bridge configs
jinja2 \
    "$app_config/naviance-auth-bridge/app/config/parameters.yml.j2" \
    "$input_data" \
    --format=json \
    > "$APP_DIR/naviance-auth-bridge/live/app/config/parameters.yml"

#naviance-student-college-bridge configs
jinja2 \
    "$app_config/naviance-student-college-bridge/app/config/parameters.yml.j2" \
    "$input_data" \
    --format=json \
    > "$APP_DIR/naviance-student-college-bridge/app/config/parameters.yml"

# assessment-api-prototype configs
mkdir -p "${APP_DIR}/navserv-beta/resources/config"
jinja2 \
    "$app_config/assessment-api-prototype/resources/config/services.json.dist.j2" \
    "$input_data" \
    --format=json \
    > "$APP_DIR/navserv-beta/resources/config/services.json.dist"

# legacy-nav-api-v1 configs
cp "$app_config/legacy-nav-api-v1/application/config/application.ini" "$APP_DIR/navserv-v1/application/config/application.ini"
jinja2 \
    "$app_config/legacy-nav-api-v1/core/config/config.xml.j2" \
    "$input_data" \
    --format=json \
    > "$APP_DIR/navserv-v1/core/config/config.xml"

# legacy-nav-api-v2 configs
mkdir -p "${APP_DIR}/navserv-beta-v2/application/config"
cp "$app_config/legacy-nav-api-v2/application/config/application.ini" "$APP_DIR/navserv-beta-v2/application/config/application.ini"
jinja2 \
    "$app_config/legacy-nav-api-v2/application/config/config.xml.j2" \
    "$input_data" \
    --format=json \
    > "$APP_DIR/navserv-beta-v2/application/config/config.xml"

# legacy-naviance-student-mobile-api configs
cp "$app_config/legacy-naviance-student-mobile-api/application/config/application.ini" "$APP_DIR/mob-api/application/config/application.ini"
jinja2 \
    "$app_config/legacy-naviance-student-mobile-api/core/config/config.xml.j2" \
    "$input_data" \
    --format=json \
    > "$APP_DIR/mob-api/core/config/config.xml"

create_webserver_config_files

SOURCE_NGINX_LOG_FORMAT="${APP_CONFIG_DIR}/hobsons-log-format.conf"
DEST_NGINX_LOG_FORMAT="/etc/nginx/hobsons-log-format.conf"
if [[ -f "$SOURCE_NGINX_LOG_FORMAT" ]]; then
    rm -f "$DEST_NGINX_LOG_FORMAT"
    ln -s "$SOURCE_NGINX_LOG_FORMAT" "$DEST_NGINX_LOG_FORMAT"
fi
