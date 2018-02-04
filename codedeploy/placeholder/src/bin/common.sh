#!/usr/bin/env bash

# This will get replaced by the real APP_NAME during the build process.
# See the Makefile for the canonical declaration of this variable.
export APP_NAME="{{ APP_NAME }}"

export APP_DIR="/opt/$APP_NAME"
export APP_CONFIG_DIR="$APP_DIR/etc"

export NGINX_SITES_AVAILABLE_APP="/etc/nginx/sites-available/$APP_NAME"
export NGINX_SITES_ENABLED_APP="/etc/nginx/sites-enabled/$APP_NAME"
export NGINX_CONF_SRC="$APP_CONFIG_DIR/nginx.conf"
export NGINX_CONF_J2="$NGINX_CONF_SRC.j2"
export NGINX_CONF_APP="/etc/nginx/conf.d/$APP_NAME.conf"
export PHP_FPM_WWW_CONF_SRC="$APP_CONFIG_DIR/www.conf"
export PHP_FPM_WWW_CONF_J2="$PHP_FPM_WWW_CONF_SRC.j2"
export PHP_FPM_WWW_CONF_APP="/etc/php-fpm.d/www.conf"
export HTTPD_CONF_SRC="$APP_CONFIG_DIR/httpd.conf"
export HTTPD_CONF_J2="$HTTPD_CONF_SRC.j2"
export HTTPD_CONF_APP="/etc/httpd/conf.d/$APP_NAME.conf"

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/manage-aws.sh"

log_file=( "/var/log/phperror.log" "/var/tmp/*.log" )
export log_file

get_os_distribution() {
    lsb_release -si
}

get_os_major_version() {
    lsb_release -sr | cut -d\. -f 1
}

get_dist_json() {
    local dist
    dist="$(get_os_distribution)"
    case "$dist" in
        Debian|Ubuntu)
            echo "$APP_CONFIG_DIR/debian.json"
            ;;
        Redhat|CentOS)
            echo "$APP_CONFIG_DIR/centos.json"
            ;;
        *)
            echo "ERROR: Unknown OS Release $dist" >2
            exit 1
            ;;
    esac
}

# Use j2cli to create versions of config files appropriate for the environment
create_webserver_config_files() {
    local dist
    local dist_json
    dist="$(get_os_distribution)"
    dist_json="$(get_dist_json)"
    jinja2 "$NGINX_CONF_J2" "$dist_json" > "$NGINX_CONF_SRC"
    jinja2 "$PHP_FPM_WWW_CONF_J2" "$dist_json" > "$PHP_FPM_WWW_CONF_SRC"
    jinja2 "$HTTPD_CONF_J2" "$dist_json" > "$HTTPD_CONF_SRC"
}

get_webserver() {
    # Prefer nginx if it is installed, but use
    # Apache httpd otherwise.
    local dist
    local version
    dist="$(get_os_distribution)"
    version=$(get_os_major_version)
    case "$dist" in
        Debian|Ubuntu)
            # shellcheck disable=SC2016
            if [[ "$(dpkg-query -W -f='${Status}' nginx)" == "install ok installed" ]]; then
                echo "nginx"
            elif [[ "$(dpkg-query -W -f='${Status}' apache2)" == "install ok installed" ]]; then
                echo "apache2"
            fi
            ;;
        Redhat|CentOS)
            set +x
            if rpm -q nginx > /dev/null; then
                echo "nginx"
            elif rpm -q httpd > /dev/null; then
                echo "httpd"
            fi
            set -x
            ;;
        *)
            echo "ERROR: OS Distribution $dist not supported"
            return 1
            ;;
    esac
}

get_php_fpm() {
    local dist
    local version
    dist="$(get_os_distribution)"
    version=$(get_os_major_version)
    case "$dist" in
        Debian|Ubuntu)
            echo "php5.6-fpm"
            ;;
        Redhat|CentOS)
            echo "php-fpm"
            ;;
        *)
            echo "ERROR: OS Distribution $dist not supported"
            return 1
            ;;
    esac
}

# Ensure web server is disabled on boot
disable_webserver() {
    local webserver
    local php_fpm
    local dist
    local version
    webserver=$(get_webserver)
    php_fpm=$(get_php_fpm)
    dist=$(get_os_distribution)
    version=$(get_os_major_version)
    case "$dist" in
        Debian|Ubuntu)
            systemctl disable "$webserver"
            systemctl disable "$php_fpm"
            rm -f "$NGINX_SITES_ENABLED_APP" "$NGINX_SITES_AVAILABLE_APP"
            ;;
        Redhat|CentOS)
            case "$version" in
                6) 
                    chkconfig "$webserver" off
                    chkconfig "$php_fpm" off
                    rm -f "$NGINX_CONF_APP"
                    ;;
                7) 
                    systemctl disable "$webserver"
                    systemctl disable "$php_fpm"
                    firewall-cmd  --remove-service=http --permanent
                    firewall-cmd  --reload
                    rm -f "$NGINX_CONF_APP"
                    ;;
                *)
                echo "ERROR: Unknown OS version $dist $version"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "ERROR: Unknown OS Release $dist"
        exit 1
        ;;
esac
}

# Ensure web server is enabled on boot
enable_webserver() {
    local webserver
    local php_fpm
    local dist
    local version
    webserver=$(get_webserver)
    php_fpm=$(get_php_fpm)
    dist=$(get_os_distribution)
    version=$(get_os_major_version)
    case "$dist" in
        Debian|Ubuntu)
            rm -f \
                "$NGINX_CONF_APP" \
                "$NGINX_SITES_ENABLED_APP" \
                "$NGINX_SITES_AVAILABLE_APP" \
                /etc/nginx/sites-enabled/default
            systemctl enable "$webserver"
            systemctl enable "$php_fpm"
            ln -s "$NGINX_CONF_SRC" "$NGINX_CONF_APP" 
            ln -s "$NGINX_CONF_APP" "$NGINX_SITES_AVAILABLE_APP"
            ln -s "$NGINX_SITES_AVAILABLE_APP" "$NGINX_SITES_ENABLED_APP"
            ;;
        Redhat|CentOS)
            case "$version" in
                6) 
                    chkconfig "$webserver" on
                    ;;
                7) 
                    systemctl enable "$webserver"
                    systemctl enable "$php_fpm"
                    firewall-cmd  --add-service=http --permanent
                    firewall-cmd  --reload
                    ;;
                *)
                echo "ERROR: Unknown OS version $dist $version"
                exit 1
                ;;
            esac
            rm -f "$NGINX_CONF_APP" /etc/nginx/conf.d/default.conf "$PHP_FPM_WWW_CONF_APP"
            ln -s "$NGINX_CONF_SRC" "$NGINX_CONF_APP" 
            cp "$PHP_FPM_WWW_CONF_SRC" "$PHP_FPM_WWW_CONF_APP" 
            ;;
        *)
            echo "ERROR: Unknown OS Release $dist"
            exit 1
            ;;
    esac
}

start_webserver() {
    local webserver
    local php_fpm
    webserver=$(get_webserver)
    php_fpm=$(get_php_fpm)
    service "$webserver" start
    if [[ "$webserver" == "nginx" ]]; then
        service "$php_fpm" start
    fi
}

stop_webserver() {
    local webserver
    local php_fpm
    webserver=$(get_webserver)
    php_fpm=$(get_php_fpm)
    service "$webserver" stop
    if [[ "$webserver" == "nginx" ]]; then
        service "$php_fpm" stop
    fi
}

clean_app_directory() {
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR"
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
