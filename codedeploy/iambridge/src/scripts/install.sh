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

INSTALL_DIR="$APP_DIR"
MEMORY_PERCENT=0.8

total_mem=$(($(awk '/MemTotal/{print $2}' < /proc/meminfo) / 1024 ))
available_mem=$(printf %.0f "$(echo "$total_mem * $MEMORY_PERCENT" | bc -l)")

cat > "/etc/systemd/system/$APP_NAME.service" << __EOF__
[Unit]
Description=$APP_NAME

[Service]
User=$APP_USER
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/java -Xmx${available_mem}M -Xms${available_mem}M  -javaagent:newrelic/newrelic.jar -jar $JAR_NAME  --spring.config.location=$CONFIG
SuccessExitStatus=143
StandardOutput=null

[Install]
WantedBy=multi-user.target

__EOF__

systemctl daemon-reload

