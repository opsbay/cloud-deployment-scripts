#!/usr/bin/env bash

# Retries a command a with backoff.
#
# The retry count is given by ATTEMPTS (default 5), the
# initial backoff timeout is given by TIMEOUT in seconds
# (default 1.)
#
# Successive backoffs double the timeout.
# Beware of set -e killing your whole script!
#
# Thanks to Coderwall
#   --> https://coderwall.com/p/--eiqg/exponential-backoff-in-bash
function try_with_backoff {
    local max_attempts=${ATTEMPTS-6}
    local timeout=${TIMEOUT-1}
    local attempt=0
    local exitCode=0

    while [[ $attempt < $max_attempts ]]
    do
        "$@"
        exitCode=$?

        if [[ $exitCode == 0 ]]
        then
            break
        fi

        echo "Failure! Retrying in $timeout.." 1>&2
        sleep "$timeout"
        attempt=$(( attempt + 1 ))
        timeout=$(( timeout * 2 ))
    done

    if [[ $exitCode != 0 ]]
    then
        #shellcheck disable=SC2145
        echo "You've failed me for the last time! ($@)" 1>&2
    fi

    return $exitCode
}

function download_newrelic_key_from_s3 {
    local tempAccountData
    local tempAccountId
    local accountId
    local s3bucket
    local tempfile
    local newrelic_key

    # Figure out what account we're in use hobsons-naviancedev as a default
    tempAccountData=$(try_with_backoff curl -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document)
    tempAccountId=$(echo "$tempAccountData" | awk -F '"' '/accountId/ { print $4 }')
    accountId=${tempAccountId:-253369875794}

    # Set s3bucket name and file location
    s3bucket="unmanaged-app-config-${accountId}"

    # Download the tenable key in a temporary file
    tempfile=$(mktemp)
    try_with_backoff aws s3 cp "s3://${s3bucket}/newrelic/newrelic-license.txt" "$tempfile" 2>&1 | logger -t newreliclinker

    # Save it in the global var and remove the temp file
    #shellcheck disable=SC1090
    newrelic_key=$(grep NEW_RELIC_KEY "${tempfile}" | awk -F '=' '{print $2}')
    rm -f "$tempfile"
    echo "$newrelic_key"
}

function configure_newrelic {
    local newrelic_key
    newrelic_key=$(download_newrelic_key_from_s3)
    nrsysmond-config --set license_key="$newrelic_key"
}
