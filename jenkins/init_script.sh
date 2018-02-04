#!/usr/bin/env bash
# init_script.sh
#
# This file lives in GitHub https://github.com/naviance/cloud-deployment-scripts
# in /jenkins/init_script.sh

set -euo pipefail
IFS=$'\n\t'

set -x

# https://jira.hobsons.com/browse/NAWS-601
# Skip initialization if we are reconnecting
INIT_FLAG=/var/jenkins/.jenkins-build-executor-initialized
if [[ ! -f "$INIT_FLAG" ]]; then
    touch "$INIT_FLAG"
fi

echo "Mount points:"
mount
echo "Disk free:"
df
