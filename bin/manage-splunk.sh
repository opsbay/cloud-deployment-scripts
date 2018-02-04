#!/usr/bin/env bash

# splunk variables
splunk_ID="admin"
splunk_password="changeme"

function manage-splunk::is_splunk_enabled() {
    local environment
    local app_name
    environment=${1:-qa}
    app_name=${2:-placeholder}
    tmpfile=$(mktemp)
    feature_file="enable_splunk.txt"
    bucket=$(get_aws_s3_app_config_bucket)
    if aws s3 cp "s3://$bucket/$environment/$app_name/$feature_file" "$tmpfile"; then
        enable_splunk=$(cat "$tmpfile")
    else
        enable_splunk="true"
    fi
    rm -f "$tmpfile"
    [[ "$enable_splunk" != "false" ]]
}

# Thanks askubuntu bash array passing syntax:
# https://askubuntu.com/a/674347
# call with:
#     manage-splunk::add_splunklogs "${log_file[@]}"
manage-splunk::add_splunklogs() {
    local log_file
    log_file=("$@")
    for log in "${log_file[@]:-}"; do
        echo "adding log $log in splunk"
        set +e
        /opt/splunkforwarder/bin/splunk add monitor "$log" -auth "$splunk_ID:$splunk_password"
        set -e
    done
}

# call with:
#     manage-splunk::remove_splunklogs "${log_file[@]}"
manage-splunk::remove_splunklogs() {
    local log_file
    log_file=("$@")
    for log in "${log_file[@]:-}"; do
        echo "removing log $log in splunk"
        set +e
        /opt/splunkforwarder/bin/splunk remove monitor "$log" -auth "$splunk_ID:$splunk_password"
        set -e
    done
}
