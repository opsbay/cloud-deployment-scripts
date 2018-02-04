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

APACHE_USER=$(get_apache_user)
APACHE_GROUP=$(get_apache_group)
mkdir -p "$APP_DIR/app/"{cache,logs}
chown -R "${APACHE_USER}:${APACHE_GROUP}" "$APP_DIR/app/"{cache,logs}
chgrp "$APACHE_GROUP" "$APP_DIR"/src/main/php/Naviance/JobQueue/Scripts/Cron/*.sh
chmod g+rx "$APP_DIR"/src/main/php/Naviance/JobQueue/Scripts/Cron/*.sh
exit 0

