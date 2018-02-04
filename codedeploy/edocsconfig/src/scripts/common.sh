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
export APP_NODE="edocs-management"
export APP_DIR="/opt/$APP_NAME"
export APP_CONFIG_DIR="$APP_DIR/etc"
export CONFIG="$APP_DIR/application-standard.yml"
export SERVER_USER="{{ SERVER_USER }}"
export JAR_NAME="{{ JAR_NAME }}"
export LOG_BASE_NAME="$APP_NAME"
export APP_PORT=8055
export MANAGEMENT_PORT=8056
export HEALTH_CHECK_PATH=/management/health

#splunk variables
log_file=( "$APP_DIR/logs/*.log" )
export log_file

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

# Pass in either a file, a socket, or a directory
label_selinux() {
    local pathspec
    local pattern
    local selinux_context
    pathspec="$1"
    selinux_context="${2:-httpd_log_t}"
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

