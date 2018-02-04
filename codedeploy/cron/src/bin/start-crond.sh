#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

# Were are no more stopping crond but we need to ensure that crond
# is running, so we are starting it to cope with corner cases.
service crond start

