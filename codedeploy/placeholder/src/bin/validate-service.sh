#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Uncomment for enhanced debugging
set -x

HEALTH_URL="${1:-http://localhost/}"

attempt="0"
max_tries="10"
while [[ "$attempt" -lt "$max_tries" ]]; do
  set +e
  HTTP_STATUS=$(curl -Is "$HEALTH_URL" | head -n 1 | tr -d '\n\r')
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
