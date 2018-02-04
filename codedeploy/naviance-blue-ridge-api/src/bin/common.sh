#!/usr/bin/env bash

# This will get replaced by the real APP_NAME during the build process.
# See the Makefile for the canonical declaration of this variable.
export APP_NAME="{{ APP_NAME }}"

export APP_DIR="/opt/$APP_NAME/www"
export APP_CONFIG_DIR="/opt/$APP_NAME/config"
export APP_USER="nobody"

export NODEJS_CONF_APP="/etc/systemd/system/nodejs.service"
export NODEJS_CONF_SRC="$APP_DIR/lib/app.js"

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/manage-aws.sh"

# Application logs for this get recorded in /var/log/messages already...
log_file=("$APP_DIR/lib/logs/*.log" "/opt/$APP_NAME/newrelic_agent.log" )
export log_file

get_os_distribution() {
    lsb_release -si
}

get_os_major_version() {
    lsb_release -sr | cut -d\. -f 1
}

get_nodejsservice() {
    # Prefer nginx if it is installed, but use
    # Apache httpd otherwise.
    local dist
    dist="$(get_os_distribution)"
    case "$dist" in
        Redhat|CentOS)
            set +x
            if rpm -q nodejs > /dev/null; then
                echo "nodejs"
            else
                echo "ERROR: no nodejs installed" 1>&2
                return 1
            fi
            set -x
            ;;
        *)
            echo "ERROR: OS Distribution $dist not supported" 1>&2
            return 1
            ;;
    esac
}

# To disable nodejs
disable_nodejs() {
    local webservice
    local dist
    webservice=$(get_nodejsservice)
    dist=$(get_os_distribution)
    case "$dist" in
        Redhat|CentOS)
            systemctl disable "$webservice"
            rm -f "$NODEJS_CONF_APP"
            firewall-cmd --remove-forward-port=port=8080:proto=tcp:toport=80 --permanent
            firewall-cmd --remove-masquerade --permanent
            firewall-cmd --reload
            ;;
        *)
            echo "ERROR: OS Distribution $dist not supported"
            return 1
            ;;
    esac
}

# Ensure nodejs is enabled on boot
enable_nodejs() {
    local webservice
    local dist
    webservice=$(get_nodejsservice)
    dist=$(get_os_distribution)
    case "$dist" in
        Redhat|CentOS)
            systemctl daemon-reload
            systemctl enable firewalld
            systemctl start firewalld
            firewall-cmd --add-masquerade --permanent
            firewall-cmd --add-forward-port=port=80:proto=tcp:toport=8080 --permanent
            firewall-cmd --reload
            sudo systemctl enable "$webservice"
            ;;
        *)
            echo "ERROR: Unknown OS Release $dist"
            exit 1
            ;;
    esac
}

# To start a nodejs service
start_nodejs() {
    local webservice
    webservice=$(get_nodejsservice)
    sudo systemctl start "$webservice"
}

# To stop a nodejs service
stop_nodejs() {
    local webservice
    webservice=$(get_nodejsservice)
    if [[ -f "$NODEJS_CONF_APP" ]]; then
        systemctl stop "$webservice"
    fi
}

# To clean the appdir
clean_app_directory() {
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR"
}

ensure_root() {
    # Thanks Stack Overflow http://stackoverflow.com/a/18216122/424301
    if [[ "$EUID" -ne 0 ]]; then
        echo "Please run as root"
        return 1
    fi
}

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
