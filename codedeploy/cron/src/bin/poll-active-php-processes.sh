#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

#TODO - Determine the best strategy for safely stopping active jobs in a timely manner, or at least check none are running prior to deployment

#Assume some php process is running for first pass
STATUS=1
while [ "$STATUS" -ne 0 ]; do
    sleep 1
    STATUS=$(/usr/bin/pgrep -x php | wc -l)
done

exit 0