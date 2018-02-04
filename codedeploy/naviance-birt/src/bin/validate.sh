#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
source "$DIR/common.sh"

HEALTH_URL="${1:-http://localhost:${APP_PORT}/whatsup/index.html}"

attempt="0"
max_tries="60"
while [[ "$attempt" -lt "$max_tries" ]]; do
  set +e
  HTTP_STATUS=$(curl -Is --connect-timeout 5 "$HEALTH_URL" | head -n 1 | tr -d '\n\r')
  if [[ "$HTTP_STATUS" =~ 200 ]]; then
    echo "$(date): Service ready"
    exit 0
  fi
  set -e
  echo "$(date): Service still not ready, status: '$HTTP_STATUS'"
  sleep 2
  attempt=$((attempt + 1))
done

echo "$(date): Service ${HEALTH_URL} failed health check"
echo "$(date): HTTP Status: $HTTP_STATUS"

exit 1