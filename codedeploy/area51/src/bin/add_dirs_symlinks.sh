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

for file in "${APP_DIR}" "${CACHE_DIR}" "${BACKUP_DIR}" "${LOCK_DIR}"
do
    mkdir -p "$APP_DIR"
    chown -R "${WEBSERVER_USER}:${WEBSERVER_GROUP}" "${APP_DIR}"
    label_selinux "${APP_DIR}"
done

# Ensure php error log exists and is writable
for file in "${PHP_ERROR_LOG}" "${AREA51_SUPPORT_LOG}" "${AREA51_ACCESS_LOG}" "${AREA51_JOBS_LOG}" "${AREA51_REQUEST_LOG}"
do
    touch "${file}"
    chown "${WEBSERVER_USER}" "${file}"
    label_selinux "${file}"
done
