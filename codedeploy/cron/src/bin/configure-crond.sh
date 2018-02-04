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

app_dir_config="$APP_CONFIG_DIR/s3/$APP_NAME/$DEPLOYMENT_GROUP_NAME"

for user in apache etl; do
    id -u "$user" &>/dev/null || useradd "$user"
    crontab -u "$user" "$app_dir_config/cron-$user.txt"
done
