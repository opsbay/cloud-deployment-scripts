#!/usr/bin/env bash

# This will get replaced by the real APP_NAME during the build process.
# See the Makefile for the canonical declaration of this variable.
export APP_NAME="{{ APP_NAME }}"
export PHP_VERSION="{{ PHP_VERSION }}"

export APP_DIR="/httpd/$APP_NAME"
export APP_CONFIG_DIR="/opt/$APP_NAME/etc"
export APP_CONFIG_COMMON_DIR="/opt/$APP_NAME/codedeploy/common/"

export NGINX_SITES_AVAILABLE_APP="/etc/nginx/sites-available/$APP_NAME"
export NGINX_SITES_ENABLED_APP="/etc/nginx/sites-enabled/$APP_NAME"

export NGINX_CONF_SRC="$APP_CONFIG_DIR/nginx.conf"
export NGINX_CONF_J2="$NGINX_CONF_SRC.j2"
export NGINX_CONF_APP="/etc/nginx/conf.d/$APP_NAME.conf"

# Vhost config
export HTTPD_VHOST_CONF_APP="/etc/httpd/conf.d/$APP_NAME.conf"

export CENTOS_CONFIGS="centos.$PHP_VERSION.json"
export DEBIAN_CONFIGS="debian.$PHP_VERSION.json"

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/manage-aws.sh"

log_file=( "/var/log/phperror.log" "/httpd/succeed/app/logs/*" "/var/log/naviance/*")
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
            echo "$APP_CONFIG_DIR/$DEBIAN_CONFIGS"
            ;;
        Redhat|CentOS)
            echo "$APP_CONFIG_DIR/$CENTOS_CONFIGS"
            ;;
        *)
            echo "ERROR: Unknown OS Release $dist" >2
            exit 1
            ;;
    esac
}

# See: http://blog.frag-gustav.de/2013/07/21/nginx-selinux-me-mad/
disable_selinux_httpd_connect() {
    setsebool -P httpd_can_network_connect 0
}

enable_selinux_httpd_connect() {
    setsebool -P httpd_can_network_connect 1
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

get_server_name_json() {
    local server_name

    case "$DEPLOYMENT_GROUP_NAME" in
        staging|qa)
           server_name="tf-$APP_NAME-$PHP_VERSION-$DEPLOYMENT_GROUP_NAME.mango.naviance.com"
        ;;

        preprod)
           server_name="tf-$APP_NAME-$PHP_VERSION-$DEPLOYMENT_GROUP_NAME.papaya.naviance.com"
        ;;

        production)
            server_name="$APP_NAME.naviance.com"
        ;;

        *)
            echo "ERROR: Unsupported DEPLOYMENT_GROUP_NAME: $DEPLOYMENT_GROUP_NAME"
            exit 1
        ;;
    esac

    cat <<EMITTED_JSON
{
    "serverName": "$server_name"
}
EMITTED_JSON
}

# Use j2cli to create versions of config files appropriate for the environment
create_webserver_config_files() {
    local input_json
    local emitted_json
    local dist
    local dist_json
    dist="$(get_os_distribution)"
    dist_json="$(get_dist_json)"
    input_json=$(mktemp)
    emitted_json=$(mktemp)
    get_server_name_json > "$emitted_json"

    #shellcheck disable=SC2016
    cat "$dist_json" "$emitted_json"  \
        | jq --slurp 'reduce .[] as $item ({}; . + $item)' \
        > "$input_json"

    jinja2 \
        "$NGINX_CONF_J2" \
        "$input_json" \
        --format=json \
        > "$NGINX_CONF_SRC"

    rm -f "$emitted_json" "$input_json"
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
            case "$version" in
                6)
                    echo 'httpd'
                    ;;
                7)
                    echo 'nginx'
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

set_webserver_user_limits() {
    local limits_file
    limits_file="/etc/systemd/system/php-fpm.service.d/limits.conf"
    printf '[Service]\nLimitSTACK=67108864\n' > $limits_file
    chmod 0500 "$limits_file"
    systemctl daemon-reload
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
    version=$(get_os_major_version)
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
            case "$version" in
                6)
                    webserver_user="apache"
                    ;;
                7)
                    webserver_user="nginx"
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

    # shellcheck disable=SC2002
    webuser_exists=$(cat "$APP_CONFIG_DIR/$conf_file" | jq "$what_key")
    if [[ "$webuser_exists" != "null" ]]; then
        jq -r "$what_key" "$APP_CONFIG_DIR/$conf_file"
        return 0
    fi
    echo "$webserver_user"
}

disable_webserver() {
# Ensure web server is disabled on boot
    local webserver
    local dist
    local version
    webserver=$(get_webserver)
    dist=$(get_os_distribution)
    version=$(get_os_major_version)

    case "$dist" in
        Debian|Ubuntu)
            systemctl disable "$webserver"
            systemctl disable php-fpm
            rm -f "$NGINX_SITES_ENABLED_APP" "$NGINX_SITES_AVAILABLE_APP"
            ln -s "$NGINX_CONF_APP" "$NGINX_SITES_AVAILABLE_APP"
            ln -s "$NGINX_SITES_AVAILABLE_APP" "$NGINX_SITES_ENABLED_APP"
            ;;
        Redhat|CentOS)
            case "$version" in
                6)
                    chkconfig "$webserver" off
                    rm -f "$HTTPD_VHOST_CONF_APP"
                    ;;
                7)
                    systemctl disable "$webserver"
                    systemctl disable php-fpm
                    firewall-cmd --remove-service=http --permanent
                    firewall-cmd --reload
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
    local dist
    local version
    webserver=$(get_webserver)
    dist=$(get_os_distribution)
    version=$(get_os_major_version)

    case "$dist" in
        Debian|Ubuntu)
            systemctl enable "$webserver"
            systemctl enable php-fpm
            rm -f "$NGINX_SITES_AVAILABLE"  /etc/nginx/sites-enabled/default
            ln -s "$NGINX_CONF_SRC" "$NGINX_CONF_APP"
            ;;
        Redhat|CentOS)
            case "$version" in
                6)
                    chkconfig "$webserver" on                    
                    /usr/bin/setfacl -dm g:splunk:r  /var/log/httpd
                    /usr/bin/setfacl -m  g:splunk:rx /var/log/httpd
                    ;;
                7)
                    set_webserver_user_limits
                    systemctl enable "$webserver"
                    systemctl enable php-fpm
                    firewall-cmd --add-service=http --permanent
                    firewall-cmd --reload
                    rm -f "$NGINX_CONF_APP" /etc/nginx/conf.d/default.conf
                    ln -s "$NGINX_CONF_SRC" "$NGINX_CONF_APP"
                    /usr/bin/setfacl -dm g:splunk:r  /var/log/nginx
                    /usr/bin/setfacl -m  g:splunk:rx /var/log/nginx
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

start_webserver() {
    local webserver
    webserver=$(get_webserver)

    service "$webserver" start
    if [[ "$webserver" == "nginx" ]]; then
        service php-fpm start
    fi
}


stop_webserver() {
    local webserver
    webserver=$(get_webserver)

    service "$webserver" stop
    if [[ "$webserver" == "nginx" ]]; then
        service php-fpm stop
    fi
}

clean_app_directory() {
    rm -rf "$APP_DIR" "/opt/$APP_NAME"
    mkdir -p "$APP_DIR" "/opt/$APP_NAME"
}

create_log_dir() {
    local log_dir
    local webserver_user
    local webserver_group
    log_dir=${1:-}
    webserver_user=${2:-}
    webserver_group=${3:-}

    mkdir -p "$log_dir"
    chown "$webserver_user:$webserver_group" "$log_dir"
    chmod 0750 "$log_dir"
    label_selinux "$log_dir"
    setfacl -m  g:splunk:rx -R "$log_dir"
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