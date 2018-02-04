#!/usr/bin/env bash

set -x

# Thanks Stack Overflow http://stackoverflow.com/a/18216122/424301
if [[ "$EUID" -ne 0 ]]
  then echo "Please run as root"
  exit
fi

# This will get replaced by the real APP_NAME during the build process.
# See the Makefile for the canonical declaration of this variable.
export APP_NAME="nodejs"

export APP_DIR="/opt/$APP_NAME"
#export APP_CONFIG_DIR="$APP_DIR/nodejs"

export NODEJS_CONF_APP="/etc/systemd/system/$APP_NAME.service"
export NODEJS_CONF_SRC="$APP_DIR/sample.js"

get_aws_region() {
    local aws_region

    if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
        aws_region="$AWS_DEFAULT_REGION"
    elif read -r region < <(aws configure get default.region); then
        aws_region="$region"
    else
        # Thanks Stack Overflow http://stackoverflow.com/a/9263531/424301
        local identity_doc="http://169.254.169.254/latest/dynamic/instance-identity/document"
        aws_region=$(curl -s "$identity_doc" | awk -F\" '/region/ {print $4}')
    fi

    if [[ -z "$aws_region" ]]; then
        echo 'ERROR: The AWS region could not be acquired. Terminating.'
        exit 1
    fi

    echo "$aws_region"
}

get_aws_account_id() {
    local account_id

    # Thanks Stack Overflow https://stackoverflow.com/a/40121084/424301
    account_id=$(aws sts get-caller-identity \
        --output text \
        --query 'Account' \
        --region "$(get_aws_region)")

    if [[ -z "$account_id" ]]; then
        account_id=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.accountId')
    fi

    if [[ -z "$account_id" ]]; then
        echo 'ERROR: The AWS accound ID could not be acquired. Terminating.'
        exit 1
    fi

    echo "$account_id"
}

get_aws_s3_app_config_bucket() {
    echo "unmanaged-app-config-$(get_aws_account_id)"
}

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

# To diable nodejs
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

            systemctl enable "$webservice"
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
    systemctl start "$webservice"
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