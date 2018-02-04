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

cat << EOF >/etc/rsyslog.d/10-custom.conf
if \$programname == 'edocslogs' then {
    $APP_DIR/logs/$LOG_BASE_NAME.log
	~
}
EOF

systemctl restart rsyslog

label_selinux "$APP_DIR/logs/$LOG_BASE_NAME.log"
label_selinux "$APP_DIR/logs/$LOG_BASE_NAME-error.log"
