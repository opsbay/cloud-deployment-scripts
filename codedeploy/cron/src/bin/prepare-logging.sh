#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
source "$DIR/common.sh"

APP_USER=apache

function create_log_dir() {
    local logDir=${1:-}
    mkdir -p "$logDir" # legacy logging location, remove after NAWS-226 is resolved
    chown $APP_USER:$APP_USER "$logDir"
    chmod 0750 "$logDir"
    setfacl -m  g:splunk:rx -R "$logDir"
}

create_log_dir "/var/log/naviance"

# FIXME: legacy logging location, remove after NAWS-226 is resolved
create_log_dir "$APP_DIR/lib/logs"
