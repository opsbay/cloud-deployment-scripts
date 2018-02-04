#!/bin/bash

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

if getent passwd "${SERVER_USER}" > /dev/null ; then
  # nothing to do as user already exists
  echo "Skipping Create User as user '${SERVER_USER}' already exists"
else
  echo "Creating user: ${SERVER_USER}"
  if ! useradd -m "${SERVER_USER}"; then
    echo "Unable to provision user account as: useradd -m '${SERVER_USER}'"
    exit 1
  fi
  echo "Created user: ${SERVER_USER}"
fi

if [ -d "${APP_DIR}" ] ; then
  rm -rf "${APP_DIR}"
fi

mkdir -p "$APP_DIR/logs"
touch "$APP_DIR/logs/$LOG_BASE_NAME.log"
touch "$APP_DIR/logs/$LOG_BASE_NAME-error.log"
chown -R "$SERVER_USER:$SERVER_USER" "$APP_DIR"
chgrp "$SERVER_USER"  "$APP_DIR/logs"
chmod g+w "$APP_DIR/logs"

firewall-cmd --add-port="$APP_PORT/tcp" --permanent
firewall-cmd --add-port="$MANAGEMENT_PORT"/tcp --permanent

firewall-cmd --reload

mkdir -p "${APP_DIR}"
