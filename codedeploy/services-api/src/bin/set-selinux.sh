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

enable_selinux_httpd_connect
label_selinux "$APP_DIR" httpd_sys_content_t
label_selinux "$APP_DIR/naviance-auth-bridge/live/app/cache" httpd_sys_rw_content_t
label_selinux "$APP_DIR/naviance-auth-bridge/live/app/logs" httpd_sys_rw_content_t
label_selinux "$APP_DIR/naviance-student-college-bridge/app/cache" httpd_sys_rw_content_t
label_selinux "$APP_DIR/naviance-student-college-bridge/app/logs" httpd_sys_rw_content_t
label_selinux "$APP_DIR/navserv-beta/resources" httpd_sys_rw_content_t
