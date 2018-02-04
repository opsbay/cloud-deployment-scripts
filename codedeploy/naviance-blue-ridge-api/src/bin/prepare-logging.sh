#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$DIR/common.sh"

# Enable this to debug these scripts
set -x

function create_log_dir() {
    local logDir=${1:-}
    mkdir -p "$logDir" # legacy logging location, remove after NAWS-226 is resolved
    chown "$APP_USER:$APP_USER" "$logDir"
    chmod 0750 "$logDir"
}

create_log_dir "/var/log/$APP_NAME"

# FIXME: legacy logging location, remove after NAWS-226 is resolved
create_log_dir "$APP_DIR/lib/logs"

# FIXME: temp fix, bake this into the packer image
# https://jira.hobsons.com/browse/NAWS-1318
/usr/bin/setfacl -dm g:splunk:r  /var/log/audit
/usr/bin/setfacl -m  g:splunk:r  /var/log/audit/audit.log
/usr/bin/setfacl -m  g:splunk:rx /var/log/audit
