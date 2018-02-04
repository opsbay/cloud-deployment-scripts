#!/usr/bin/env bash

# This will get replaced by the real APP_NAME during the build process.
# See the Makefile for the canonical declaration of this variable.
export APP_NAME="{{ APP_NAME }}"

export APP_DIR="/var/www/applications/succeed"
export APP_CONFIG_DIR="/opt/$APP_NAME/etc"
export PHP_VERSION="{{ PHP_VERSION }}"

export NJQ_CRON_SRC="$APP_CONFIG_DIR/crontab"

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/manage-aws.sh"

#splunk variables
log_file=( "/var/log/phperror.log" "/var/log/naviance/*" )
export log_file

get_os_distribution() {
    lsb_release -si
}

get_os_major_version() {
    lsb_release -sr | cut -d\. -f 1
}

get_server_name_json() {
    local server_name

    # FIXME: This has to be fixed before the actual cutover because we are hardcoding some values
    # in for now.
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

# Ensure web server is disabled on boot
disable_batch() {
    local dist
    local version
    dist=$(get_os_distribution)
    version=$(get_os_major_version)
    case "$dist" in
        Debian|Ubuntu)
            systemctl disable atd
            systemctl disable crond
            crontab -u "$(get_apache_user)" -r || true
            rm -f "$NJQ_CRON_SRC"
            ;;
        Redhat|CentOS)
            case "$version" in
                6)
                    chkconfig atd off
                    chkconfig crond off
                    crontab -u "$(get_apache_user)" -r || true
                    rm -f "$NJQ_CRON_SRC"
                    ;;
                7)
                    systemctl disable atd
                    systemctl disable crond
                    crontab -u "$(get_apache_user)" -r || true
                    rm -f "$NJQ_CRON_SRC"
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

set_nproc_limit() {
    local user
    local limit
    local is_set
    local nproc_file

    # Note: For Ubuntu there is a bug that makes limits.conf ignored
    # https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/1627769

    user="$1"
    limit="$2"
    nproc_file="/etc/security/limits.d/apache.conf"
    set +e
    is_set="$(grep -c "$user" "$nproc_file" 2>/dev/null)"
    set -e

    if [[ "$is_set" == "1" ]] ; then
        # Update existent value
        sed -i.backup -e "s/$user *soft *nproc .*$/$user soft nproc $limit/" $nproc_file
        rm -f "$nproc_file.backup"
    else
        # Add the user limit
        echo "$user soft nproc $limit" > $nproc_file
    fi

    chmod 0644 "$nproc_file"
}

enable_at_for_http_user() {
    get_apache_user > /etc/at.allow
}

# Ensure web server is enabled on boot
enable_batch() {
    local dist
    local version
    local user
    dist=$(get_os_distribution)
    version=$(get_os_major_version)
    user="$(get_apache_user)"
    case "$dist" in
        Debian|Ubuntu)
            systemctl enable atd
            systemctl enable crond
            ;;
        Redhat|CentOS)
            case "$version" in
                6)
                    chkconfig atd on
                    chkconfig crond on
                    ;;
                7)
                    systemctl enable atd
                    systemctl enable crond
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

    crontab -u "$user" "$NJQ_CRON_SRC"
    set_nproc_limit "$user" 10240
}

start_batch() {
    local dist
    local version
    dist=$(get_os_distribution)
    version=$(get_os_major_version)
    case "$dist" in
        Debian|Ubuntu)
            systemctl start atd
            systemctl start crond
            ;;
        Redhat|CentOS)
            case "$version" in
                6)
                    service atd start
                    service crond start
                    ;;
                7)
                    systemctl start atd
                    systemctl start crond
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

stop_batch() {
    local dist
    local version
    dist=$(get_os_distribution)
    version=$(get_os_major_version)
    case "$dist" in
        Debian|Ubuntu)
            systemctl stop atd
            systemctl stop crond
            ;;
        Redhat|CentOS)
            case "$version" in
                6)
                    service atd stop
                    service crond stop
                    ;;
                7)
                    systemctl stop atd
                    systemctl stop crond
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

# Echo's the Apache user based on the distro.
# Depends on the existance of /opt/$APP_NAME/etc/(centos|debian).json
get_apache_user() {
    local dist
    dist=$(get_os_distribution)
    local conf_file

    case "$dist" in
        Debian|Ubuntu)
            conf_file="debian.json"
            ;;

        Redhat|CentOS)
            conf_file="centos.json"
            ;;

        *)
            echo "ERROR: Unknown OS Release $dist"
            exit 1
            ;;
    esac

    jq -r '.wwwUser' "$APP_CONFIG_DIR/$conf_file"
}

# Echo's the Apache group based on the distro.
# Depends on the existance of /opt/$APP_NAME/etc/(centos|debian).json
get_apache_group() {
    local dist
    dist=$(get_os_distribution)
    local conf_file

    case "$dist" in
        Debian|Ubuntu)
            conf_file="debian.json"
            ;;

        Redhat|CentOS)
            conf_file="centos.json"
            ;;

        *)
            echo "ERROR: Unknown OS Release $dist"
            exit 1
            ;;
    esac

    jq -r '.wwwGroup' "$APP_CONFIG_DIR/$conf_file"
}

clean_app_directory() {
    rm -rf "$APP_DIR" "/opt/$APP_NAME"
    mkdir -p "$APP_DIR" "/opt/$APP_NAME"
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
