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

# mkdir -p "$APP_DIR/app/"{cache,logs}
mkdir -p "$APP_DIR"

webserver_user=$(get_webserver_info user)
webserver_group=$(get_webserver_info group)
chown -R "${webserver_user}:${webserver_group}" "${APP_DIR}"

semlogs_dir='/usr/local/smlogs/'
mkdir -p "$semlogs_dir"
chown -R "${webserver_user}:${webserver_group}" "${semlogs_dir}"
chmod 0770 "${semlogs_dir}"

enrichmentalley_dir='/usr/local/enrichmentalley/'
mkdir -p "$enrichmentalley_dir"
chown -R "${webserver_user}:${webserver_group}" "${enrichmentalley_dir}"
chmod 0770 "${enrichmentalley_dir}"

label_selinux "$semlogs_dir"
label_selinux "$enrichmentalley_dir"
label_selinux "/var/log/phperror.log"
