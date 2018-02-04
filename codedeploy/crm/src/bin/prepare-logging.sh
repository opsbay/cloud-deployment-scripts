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

webserver_user=$(get_webserver_info user)
webserver_group=$(get_webserver_info group)

create_log_dir "/var/log/naviance" "$webserver_user" "$webserver_group"

# https://jira.hobsons.com/browse/NAWS-803
# Create phperror.log file
phperrorlog=/var/log/phperror.log
touch "$phperrorlog"
chown "$webserver_user:$webserver_group" "$phperrorlog"
label_selinux "$phperrorlog"

exit 0
