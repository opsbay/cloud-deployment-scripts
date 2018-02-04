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

S3_BUCKET=$(get_aws_s3_app_config_bucket)
CONFIG_DIR="$APP_CONFIG_DIR/s3"

# See https://aws.amazon.com/blogs/devops/using-codedeploy-environment-variables/
environment=${DEPLOYMENT_GROUP_NAME:-qa}

rm -rf "$CONFIG_DIR"
mkdir -p "${CONFIG_DIR}"/{elasticache,aurora-cluster,db}

cache_data="${CONFIG_DIR}/elasticache/cache_configuration_endpoint_data.json"
cache_session="${CONFIG_DIR}/elasticache/cache_configuration_endpoint_session.json"
aurora_endpoint="${CONFIG_DIR}/aurora-cluster/aurora-cluster-endpoint.json"
aurora_config=$(get_config_by_env aurora)
cache_s_config=$(get_config_by_env cache_s)
cache_d_config=$(get_config_by_env cache_d)
FC_APP_NAME="family-connection"
# Download connection info from S3
aws s3 cp "s3://${S3_BUCKET}/aurora-cluster/aurora-cluster-creds.json"              "${CONFIG_DIR}/aurora-cluster/"
aws s3 cp "$aurora_config"                                                          "$aurora_endpoint"
aws s3 cp "$cache_s_config"                                                         "$cache_session"
aws s3 cp "$cache_d_config"                                                         "$cache_data"
aws s3 cp "s3://${S3_BUCKET}/${environment}/db/naviance.json"                       "${CONFIG_DIR}/db/"
aws s3 cp "s3://${S3_BUCKET}/${environment}/db/edocs.json"                          "${CONFIG_DIR}/db/"
aws s3 cp "s3://${S3_BUCKET}/${environment}/db/mobile.json"                         "${CONFIG_DIR}/db/"

# Download config files from s3
mkdir -p "${CONFIG_DIR}"/$FC_APP_NAME/{app,php}
aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/app/config.xml.j2"        "${CONFIG_DIR}/$FC_APP_NAME/app/"
aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/app/crmConfig.php"        "${APP_DIR}/config/"
aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/app/dbConfig.php.j2"      "${CONFIG_DIR}/$FC_APP_NAME/app/"
aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/app/mapquestConfig.php"   "${APP_DIR}/config/"
aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/app/salesforceConfig.php" "${APP_DIR}/config/"
aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/app/wk12Config.php.j2"    "${CONFIG_DIR}/$FC_APP_NAME/app/"

# Download php config files from s3
if [[ "$PHP_VERSION" == "53" ]] ; then
    aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/php/apc.ini"   /etc/php.d/apc.ini
fi
aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/php/53/php.ini.j2" "${CONFIG_DIR}/$FC_APP_NAME/php/php.53.ini.j2"
aws s3 cp "s3://${S3_BUCKET}/${environment}/$FC_APP_NAME/php/56/php.ini.j2" "${CONFIG_DIR}/$FC_APP_NAME/php/php.56.ini.j2"

for user in apache cronuser etl; do
    aws s3 cp "s3://${S3_BUCKET}/${environment}/${APP_CONFIG}/cron-$user.txt" "${CONFIG_DIR}/"
done

naviance_creds="${CONFIG_DIR}/db/naviance.json"
edocs_creds="${CONFIG_DIR}/db/edocs.json"
mobile_creds="${CONFIG_DIR}/db/mobile.json"
input_data="${CONFIG_DIR}/input_data.json"

#shellcheck disable=SC2016
printf '{"php_version": "%s"}\n' "$PHP_VERSION" \
    | cat - "$aurora_endpoint" "$naviance_creds" "$edocs_creds" "$mobile_creds" "$cache_data" "$cache_session" \
    | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
    > "$input_data"

mkdir -p "${APP_DIR}/core/config"
jinja2 "${CONFIG_DIR}/$FC_APP_NAME/app/config.xml.j2"           "$input_data" --format=json > "${APP_DIR}/core/config/config.xml"
jinja2 "${CONFIG_DIR}/$FC_APP_NAME/app/dbConfig.php.j2"         "$input_data" --format=json > "${APP_DIR}/config/dbConfig.php"
jinja2 "${CONFIG_DIR}/$FC_APP_NAME/app/wk12Config.php.j2"       "$input_data" --format=json > "${APP_DIR}/config/wk12Config.php"
jinja2 "${CONFIG_DIR}/$FC_APP_NAME/php/php.$PHP_VERSION.ini.j2" "$input_data" --format=json > /etc/php.ini
