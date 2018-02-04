#!/usr/bin/env bash
declare APP_NAME
declare APP_DIR
declare APP_CONFIG_DIR
declare CONFIG
declare SERVER_USER
declare JAR_NAME
declare LOG_BASE_NAME
declare APP_PORT
declare MANAGEMENT_PORT

export APP_NAME="{{ APP_NAME }}"
export APP_DIR="/opt/naviance/$APP_NAME"
export APP_CONFIG_DIR="$APP_DIR/etc"
export APP_USER="$APP_NAME"
export CONFIG="$APP_DIR/application-standard.yml"
export SERVER_USER="$APP_NAME"
export JAR_NAME="{{ JAR_NAME }}"
export LOG_BASE_NAME="NavianceLegacyApi"
export APP_PORT=8740
export MANAGEMENT_PORT=8742
export HEALTH_CHECK_PATH=/management/health

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/manage-aws.sh"

#splunk variables
log_file=( "$APP_DIR/logs/*.log" "$APP_DIR/logs/.../*.log" )
export log_file

# Determines the config to use based on CodeDeploys DEPLOYMENT_GROUP_NAME env var.
# 
# get_config_by_env TYPE_OF_CONFIG [DEPLOYMENT_GROUP_NAME]
# 
#   get_config_by_env aurora
#   get_config_by_env aurora qa
get_config_by_env() {
    declare var_name
    declare bucket

    declare aurora
    declare cache_s
    declare cache_d

    bucket=$(get_aws_s3_app_config_bucket)
    var_name="${1}"
    #shellcheck disable=SC2034
    group_name="${2:-$DEPLOYMENT_GROUP_NAME}"

    case "$group_name" in
        "preprod"|"staging")
            aurora="s3://$bucket/aurora-cluster/aurora-cluster-perftest-endpoint.json"
            cache_s="s3://$bucket/elasticache/tf-perftest-cache-s.json"
            cache_d="s3://$bucket/elasticache/tf-perftest-cache-d.json"
            ;;

        # qa, production
        *)
            #shellcheck disable=SC2034
            aurora="s3://$bucket/aurora-cluster/aurora-cluster-endpoint.json"
            #shellcheck disable=SC2034
            cache_s="s3://$bucket/elasticache/tf-testapp-p-cache-s.json"
            #shellcheck disable=SC2034
            cache_d="s3://$bucket/elasticache/tf-testapp-p-cache-d.json"
            ;;
    esac

    echo "${!var_name}"
}
