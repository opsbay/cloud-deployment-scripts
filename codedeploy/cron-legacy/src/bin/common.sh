#!/usr/bin/env bash

# This will get replaced by the real APP_NAME during the build process.
# See the Makefile for the canonical declaration of this variable.
export APP_NAME="{{ APP_NAME }}"
export PHP_VERSION="{{ PHP_VERSION }}"

APPLICATION_NAME=${APPLICATION_NAME:-$APP_NAME}
APP_TARGET="$(cut -d'-' -f 5 <<<"$APPLICATION_NAME")"
export APP_TARGET

APP_CONFIG="$(cut -d'-' -f 2- <<<"$APPLICATION_NAME")"
export APP_CONFIG

export APP_DIR="/httpd/k12"
export SOURCE_DIR="/opt/naviance/$APP_NAME"
export APP_CONFIG_DIR="$SOURCE_DIR/etc"

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/manage-aws.sh"

log_file=( "/var/log/phperror.log" "/var/log/naviance/*" )
export log_file

get_os_distribution() {
    lsb_release -si
}

get_os_major_version() {
    lsb_release -sr | cut -d\. -f 1
}

# TODO: Make this work for Ubuntu, if necessary.
# Returns 0 if nginx is installed, else returns 1
nginx_installed() {
    if [[ -n "$(rpm -qa nginx)" ]]; then
        echo 0
    else
        echo 1
    fi
}
apache_installed() {
    if [[ -n "$(rpm -qa httpd)" ]]; then
        echo 0
    else
        echo 1
    fi
}

# Pass in either a file, a socket, or a directory
label_selinux() {
    local pathspec
    local pattern
    local selinux_context
    pathspec="$1"
    selinux_context="${2:-httpd_sys_rw_content_t}"
    if [[ -d "$pathspec" ]]; then
        # Strip all trailing slashes
        pathspec=$(sed -e 's/\/*$//' <<<"$pathspec")
        pattern="${pathspec}(/.*)?"
    elif [[ -f "$pathspec" ]] || [[ -S "$pathspec" ]]; then
        # pathspec is a file or a socket
        pattern="$pathspec"
    else
        echo "ERROR: label_selinux() only works on files, directories, or sockets"
        return 1
    fi

    semanage fcontext -a -t "$selinux_context" "$pattern"
    restorecon -RF "$pathspec"
}

enable_selinux_writes() {
    local target
    target="$1"
    semanage fcontext -a -t httpd_sys_rw_content_t "$target"
    restorecon -RF "$target"
}

ensure_dependencies() {
    local dist
    local version
    dist="$(get_os_distribution)"
    version=$(get_os_major_version)

    case "$dist" in
        Debian|Ubuntu)
            exit 1
            ;;

        Redhat|CentOS)
            case "$version" in
                6)
                    # https://github.com/wkhtmltopdf/wkhtmltopdf/releases/0.12.2.1
                    # https://potatocommerce.com/how-to-install-wkhtmltopdf-for-potato-pdf-extension
                    wget https://downloads.wkhtmltopdf.org/0.12/0.12.2.1/wkhtmltox-0.12.2.1_linux-centos6-amd64.rpm
                    yum install -q -y xorg-x11-fonts-75dpi \
                                      xorg-x11-fonts-Type1 \
                                      wkhtmltox-0.12.2.1_linux-centos6-amd64.rpm
                    ;;
                7)
                    if [[ ! -e '/usr/bin/wkhtmltopdf' ]] ; then
                        wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.2.1/wkhtmltox-0.12.2.1_linux-centos7-amd64.rpm
                        yum install -q -y xorg-x11-fonts-75dpi \
                                          xorg-x11-fonts-Type1 \
                                          wkhtmltox-0.12.2.1_linux-centos7-amd64.rpm
                        ln -s /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf
                    fi
                    ;;
                *)
                    echo "ERROR: Unknown OS version $dist $version"
                    exit 1
                    ;;
            esac
            ;;

        *)
            echo "ERROR: OS Distribution $dist not supported"
            return 1
            ;;
    esac
}

# Based on the distro, this will query the packages to determine if Apache or
# Nginx is in use and get the web servers user/group name based on the
# corresponding JSON conf file (like centos.json or debian.json, for example).
#
# USAGE:
#   get_webserver user # Returns user of the installed webserver
#   get_webserver group # Returns group of the installed webserver
get_webserver_info() {
    local dist
    local conf_file
    local what_key
    local webuser_exists
    local webserver_user
    local what
    dist=$(get_os_distribution)
    what="$1"

    case "$what" in
        "user")
            what_key=".wwwUser"
            ;;

        "group")
            what_key=".wwwGroup"
            ;;

        *)
            echo "ERROR: Unsupported parameter $what"
            exit 1
            ;;
    esac

    case "$dist" in
        Debian|Ubuntu)
            conf_file="$DEBIAN_CONFIGS"
            # shellcheck disable=SC2016
            if [[ "$(dpkg-query -W -f='${Status}' nginx)" == "install ok installed" ]]; then
                webserver_user="nginx"
            elif [[ "$(dpkg-query -W -f='${Status}' apache2)" == "install ok installed" ]]; then
                webserver_user="apache"
            else
                echo "ERROR: No web server is installed."
                exit 1
            fi
            ;;

        Redhat|CentOS)
            conf_file="$CENTOS_CONFIGS"
            # shellcheck disable=SC2016
            if [[ "$(nginx_installed)" -eq 0 ]]; then
                webserver_user="nginx"
            elif [[ "$(apache_installed)" -eq 0 ]]; then
                webserver_user="apache"
            else
                echo "ERROR: No web server is installed."
                exit 1
            fi
            ;;

        *)
            echo "ERROR: Unknown OS Release $dist"
            exit 1
            ;;
    esac

    # shellcheck disable=SC2002
    webuser_exists=$(cat "$APP_CONFIG_DIR/$conf_file" | jq "$what_key")
    if [[ "$webuser_exists" != "null" ]]; then
        jq -r "$what_key" "$APP_CONFIG_DIR/$conf_file"
        return 0
    fi
    echo "$webserver_user"
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
