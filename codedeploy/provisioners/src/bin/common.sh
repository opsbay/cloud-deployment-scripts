#!/usr/bin/env bash

# This will get replaced by the real APP_NAME during the build process.
# See the Makefile for the canonical declaration of this variable.
export APP_NAME="{{ APP_NAME }}"

# Unlike most other apps, FC is deployed to a non-standard dir.
export APP_DIR="/opt/$APP_NAME"
export APP_CONFIG_DIR="$APP_DIR/etc"
export PROVIDERS_CRON_SRC_J2="$APP_CONFIG_DIR/crontab.j2"
export PROVIDERS_CRON_SRC="$APP_CONFIG_DIR/crontab"

export JAVA_CRON_USER="javacron"
export JAVA_CRON_GROUP="$JAVA_CRON_USER"

declare BASE_DIRS

export BASE_DIRS=(
    "${APP_DIR}/application-data-provisioner/"
    "${APP_DIR}/college-core-provisioner/"
    "${APP_DIR}/college-destination-core-provisioner/"
    "${APP_DIR}/school-core-provisioner/"
)

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/manage-aws.sh"

# logfiles that need to be added to splunk
export log_file=(
    "${APP_DIR}/application-data-provisioner/logs/*"
    "${APP_DIR}/college-core-provisioner/logs/*"
    "${APP_DIR}/college-destination-core-provisioner/logs/*"
    "${APP_DIR}/school-core-provisioner/logs/*"
)

get_os_distribution() {
    lsb_release -si
}

get_os_major_version() {
    lsb_release -sr | cut -d\. -f 1
}

clean_app_directory() {
    for each_dir in "${BASE_DIRS[@]}"; do \
        rm -rf "${each_dir:?}/"
        mkdir -p "${each_dir}/"
    done
}

create_log_dir() {
    local log_dir
    local user
    local group
    log_dir=${1:-}
    user=${2:-}
    group=${3:-}

    mkdir -p "$log_dir"
    chown "$user:$group" "$log_dir"
    chmod 0750 "$log_dir"
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

    bucket=$(get_aws_s3_app_config_bucket)
    var_name="${1}"
    #shellcheck disable=SC2034
    group_name="${2:-$DEPLOYMENT_GROUP_NAME}"

    case "$group_name" in
        "preprod"|"staging")
            aurora="s3://$bucket/aurora-cluster/aurora-cluster-perftest-endpoint.json"
            ;;
        # qa, production
        *)
            #shellcheck disable=SC2034
            aurora="s3://$bucket/aurora-cluster/aurora-cluster-endpoint.json"
            ;;
    esac

    echo "${!var_name}"
}

ensure_user_exists () {
    local is_set
    set +e
    id -u "$JAVA_CRON_USER" 2>/dev/null
    is_set="$?"
    set -e
    if [[ "$is_set" == "1" ]] ; then
        # User does not exist
        adduser "$JAVA_CRON_USER"
    fi
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

add_java_runner () {
    declare provisioner
    declare extra_params
    declare run_file

    provisioner="$1"
    extra_params="${2:-}"
    run_file="${APP_DIR}/${provisioner}/run.sh"
    pid_folder="${APP_DIR}/${provisioner}/pid/"

    mkdir -p "$pid_folder"
    cat > "$run_file" << __EOF__
#!/bin/bash -x

# Set java's location
APP_NAME=${provisioner}
JAVA=/usr/bin/java

# Get the directory that this script resides in
DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"

\${JAVA} -javaagent:\${DIR}/../newrelic/newrelic.jar -jar \${DIR}/${provisioner}.jar --spring.config.location=\${DIR}/application.yml ${extra_params} > \${DIR}/logs/${provisioner}.log 2> \${DIR}/logs/${provisioner}-error.log &
echo "\$!" > \${DIR}/pid/cron.pid
__EOF__

    chown "${JAVA_CRON_USER}:${JAVA_CRON_GROUP}" "$pid_folder"
    chmod 0750 "$pid_folder"
    chown "${JAVA_CRON_USER}:${JAVA_CRON_GROUP}" "$run_file"
    chmod 0754 "$run_file"
}

create_crontab_file () {
    local input_json
    input_json=$(mktemp)
    echo "{ \"APP_DIR\" : \"$APP_DIR\" }" > "$input_json"

    jinja2 \
        "$PROVIDERS_CRON_SRC_J2" \
        "$input_json" \
        --format=json \
        > "$PROVIDERS_CRON_SRC"

    rm -f "$input_json"
}

enable_cron_for_javacron_user() {
    printf "%s" "${JAVA_CRON_USER}" > /etc/cron.allow
}

# Ensure web server is enabled on boot
enable_cron () {
    local dist
    local version
    local user
    dist=$(get_os_distribution)
    version=$(get_os_major_version)
    user="$JAVA_CRON_USER"
    case "$dist" in
        Debian|Ubuntu)
            systemctl enable crond
            ;;
        Redhat|CentOS)
            case "$version" in
                6)
                    chkconfig crond on
                    ;;
                7)
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

    create_crontab_file
    enable_cron_for_javacron_user
    crontab -u "$user" "$PROVIDERS_CRON_SRC"
    set_nproc_limit "$user" 10240
}

wait_for_cron_to_finish () {
    declare pid_file
    declare pid
    declare sleep_time
    declare total_elapsed

    for each_dir in "${BASE_DIRS[@]}"; do \
        pid_file="$each_dir/pid/cron.pid"
        if [ -e "$pid_file" ] ; then
            sleep_time=1
            total_elapsed=0
            pid="$(cat "$pid_file" 2>/dev/null)"
            while [ -d "/proc/$pid/" ] ; do
                echo "Waiting ($sleep_time seconds) until provisioner under $each_dir with pid $pid has finished (total elapsed $total_elapsed seconds)...";
                sleep $sleep_time;
                total_elapsed=$((total_elapsed + sleep_time))
            done
            echo "The process with pid $pid finished. Waited $total_elapsed seconds."
            rm -f "$pid_file"
        fi
    done
}

disable_cron () {
    local dist
    local version
    local user
    dist=$(get_os_distribution)
    version=$(get_os_major_version)
    user="$JAVA_CRON_USER"
    case "$dist" in
        Debian|Ubuntu)
            systemctl disable crond
            wait_for_cron_to_finish
            crontab -u "$user" -r || true
            rm -f "$PROVIDERS_CRON_SRC"
            ;;
        Redhat|CentOS)
            case "$version" in
                6)
                    chkconfig crond off
                    wait_for_cron_to_finish
                    crontab -u "$user" -r || true
                    rm -f "$PROVIDERS_CRON_SRC"
                    ;;
                7)
                    systemctl disable crond
                    wait_for_cron_to_finish
                    crontab -u "$user" -r || true
                    rm -f "$PROVIDERS_CRON_SRC"
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
