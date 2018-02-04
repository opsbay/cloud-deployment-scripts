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
try_with_backoff() {
    local max_attempts
    local timeout_duration
    local attempt
    local exitCode

    max_attempts=${ATTEMPTS-6}
    timeout_duration=${TIMEOUT-1}
    attempt=0
    exitCode=0

    while [[ $attempt < $max_attempts ]]; do
        "$@"
        exitCode=$?

        if [[ $exitCode == 0 ]]; then
            break
        fi

        echo "Failure! Retrying in $timeout_duration.." 1>&2
        sleep "$timeout_duration"
        attempt=$(( attempt + 1 ))
        timeout_duration=$(( timeout_duration * 2 ))
    done

    if [[ $exitCode != 0 ]]; then
        #shellcheck disable=SC2145
        echo "You've failed me for the last time! ($@)" 1>&2
    fi

    return $exitCode
}

# Downloads outputs.conf from the appropriate bucket (dev or prod) and adds it to Splunk.
# outputs.conf would contain the IP for the indexer.
set_splunk_config() {
    local account_data
    local aws_account_id
    local bucket

    account_data=$(try_with_backoff curl -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document)
    aws_account_id=$(echo "$account_data" | awk -F '"' '/accountId/ { print $4 }')
    bucket="unmanaged-app-config-$aws_account_id"

    aws s3 cp "s3://$bucket/splunk/outputs.conf" "/opt/splunkforwarder/etc/system/local/outputs.conf"

    RETVAL=$?
    return $RETVAL
}