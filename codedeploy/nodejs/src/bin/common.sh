#!/usr/bin/env bash

set -x

# Thanks Stack Overflow http://stackoverflow.com/a/18216122/424301
if [[ "$EUID" -ne 0 ]]
  then echo "Please run as root"
  exit
fi

# This will get replaced by the real APP_NAME during the build process.
# See the Makefile for the canonical declaration of this variable.
export APP_NAME="{{ APP_NAME }}"

export APP_DIR="/opt/$APP_NAME"
#export APP_CONFIG_DIR="$APP_DIR/nodejs"

export NODEJS_CONF_APP="/etc/systemd/system/$APP_NAME.service"
export NODEJS_CONF_SRC="$APP_DIR/sample.js"

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/manage-aws.sh"

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
