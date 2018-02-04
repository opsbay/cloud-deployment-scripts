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

# The following is a list of URLs to ping to test and ensure that they return the correct content.
# The key is the URL, and the value is a bit of text to expect in the response, with special characters
# escaped (it'll be fed to sed).
# Most of these are just looking for the correct status response header, but some of them will, under normal
# circumstances, return an error 500, which we need to differentiate from a 500 due to a server misconfiguration.
# In those cases we search for a string of text in the response body.
declare -A HEALTH_URLS
HEALTH_URLS=(
  ["http://localhost/family-connection/service/index.php/healthcheck/gtg"]="HTTP\/1\.1 200" # succeed-legacy
  ["http://localhost/auth/v1/monitor/health/run"]="HTTP\/1\.1 200"                          # naviance-auth-bridge
  ["http://localhost/student-college/v1/monitor/health/run"]="HTTP\/1\.1 200"               # naviance-student-college-bridge
  ["http://localhost/assessments/beta/oauth/token"]="HTTP\/1\.1 405"                        # assessment-api-prototype, expects 405 on GET
  ["http://localhost/services/school/index.php"]="Invalid XML"                              # succeed-legacy
  ["http://localhost/services/district/index.php"]="Invalid XML"                            # succeed-legacy
  ["http://localhost/api/rest/v1/oauth/access_token"]="HTTP\/1\.1 400"                      # succeed-legacy, expects 400 on GET
  ["http://localhost/beta/v2/oauth/access_token"]="HTTP\/1\.1 405"                          # legacy-nav-api-v2, expects 405 on GET
  ["http://localhost/mob-api/oauth/access_token"]="HTTP\/1\.1 400"                          # legacy-naviance-student-mobile-api
)

test_count="${#HEALTH_URLS[@]}"
successful_tests="0"

for health_url in "${!HEALTH_URLS[@]}"; do
  expect="${HEALTH_URLS[$health_url]}"
  attempt="0"
  max_tries="15"
  while [[ "$attempt" -lt "$max_tries" ]]; do
    set +e
    response=$(curl -is "$health_url" | sed -n -e "s/\(${expect}\)/\1/p")
    if [[  ! -z "${response}" ]]; then
      echo "$(date): Service ready"
      successful_tests=$((successful_tests + 1))
      continue 2
    fi
    set -e
    echo "$(date): Service still not ready, status: '$response'"
    sleep 2
    attempt=$((attempt + 1))
  done

  echo "$(date): Service ${health_url} failed health check"
  echo "$(date): HTTP Status: $response"
done
if [ "$successful_tests" != "$test_count" ]; then
  exit 1
fi