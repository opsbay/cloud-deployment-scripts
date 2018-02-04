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

if [[ "$PHP_VERSION" == "56" ]]; then
    if [[ ! -e "/usr/local/bin/php" ]]; then
        ln -s /bin/php /usr/local/bin/php
    fi
fi

CONFIG_DIR="$APP_CONFIG_DIR/s3"

for user in apache cronuser etl; do
    id -u "$user" &>/dev/null || useradd "$user"
    crontab -u "$user" "${CONFIG_DIR}/cron-$user.txt"
done
