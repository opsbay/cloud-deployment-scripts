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

# We want only the minimum files required to be owned by the web server
# The PHP files should be owned by user root.
# We definitely do NOT want all the files in "$APP_DIR/app" to be owned
# by the web server user!
# Doing so could open us up to attacks where if an attacker could write files as the
# httpd user they could corrupt the running server files.
webserver_user=$(get_webserver_info user)
webserver_group=$(get_webserver_info group)
mkdir -p "$APP_DIR/app/"{cache,logs}
chown -R "${webserver_user}:${webserver_group}" "${APP_DIR}"

label_selinux "$APP_DIR" httpd_sys_content_t
label_selinux "$APP_DIR/app/cache/"
label_selinux "$APP_DIR/app/logs/"
