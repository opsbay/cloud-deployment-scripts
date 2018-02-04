#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

# Were are no longer stopping / starting crond,
# instead we are deleting crontabs here.
for user in apache etl; do
    id -u "$user" &>/dev/null || useradd "$user"
    crontab -u "$user" -r
done
