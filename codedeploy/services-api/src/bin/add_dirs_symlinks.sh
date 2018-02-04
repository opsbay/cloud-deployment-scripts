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

WEBSERVER_USER=$(get_webserver_info user)

# Ensure phperror.log exists and is writable
PHP_ERROR_LOG=/var/log/phperror.log
touch "$PHP_ERROR_LOG"
chown "${WEBSERVER_USER}" "$PHP_ERROR_LOG"
label_selinux "$PHP_ERROR_LOG"
