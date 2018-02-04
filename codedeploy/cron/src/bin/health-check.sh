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

declare health_out

health_out=$("$APP_DIR"/app/console monitor:health --group=cron --env=prod)
RESULT=$?

if [ $RESULT -ne 0 ]; then
    echo "ERROR: Health check failed:"
    echo "$health_out"
    exit 1
fi

exit 0
