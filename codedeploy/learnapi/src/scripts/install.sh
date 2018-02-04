#!/bin/bash
set -euo pipefail

INSTALL_DIR=/opt/naviance/learnapi
MEMORY_PERCENT=0.8

total_mem=$(($(awk '/MemTotal/{print $2}' < /proc/meminfo) / 1024 ))
available_mem=$(printf %.0f "$(echo "$total_mem * $MEMORY_PERCENT" | bc -l)")

cat > /etc/systemd/system/learnapi.service << __EOF__
[Unit]
Description=LearnAPI

[Service]
User=learnapi
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/java -Xmx${available_mem}M -Xms${available_mem}M  -javaagent:newrelic/newrelic.jar -jar student-legacy-api.jar --spring.config.name=application-standard
SuccessExitStatus=143
StandardOutput=null

[Install]
WantedBy=multi-user.target

__EOF__

systemctl daemon-reload

chgrp -R learnapi ${INSTALL_DIR}
