#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Enable to see every shell command
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
source "$DIR/common.sh"

ensure_awscli
ensure_jq

function execute-remote-command::show-usage() {
    echo "Usage: $0 <application> <php-version> <environment> <multiplicity> <user> <keyfile> <command>"
    echo "  <application>  'cron' or 'cron-legacy'"
    echo "  <php-version>  '5.3' or '5.6'"
    echo "  <environment>  'qa' or 'staging'"
    echo "  <multiplicity> 'single' or 'many'"
    echo "  <user>         The user under which to execute the command, 'apache' or 'etl' or 'cronuser'"
    echo "  <keyfile>      The ssh keyfile to use (will use the user 'centos')"
    echo "  <command>      The command to execute on the remote server. May be multiple words."
    exit 1
}

function execute-remote-command::get-instance-ip() {
    auto_scaling_group="$1"
    aws ec2 \
        describe-instances \
        --query "Reservations[].Instances[].[PrivateIpAddress]" \
        --filters "Name=tag:aws:autoscaling:groupName,Values=${auto_scaling_group}" "Name=instance-state-name,Values=running" \
        | jq -r '.[0] | .[0]'
}
if [[  $# -le 6 ]]; then
    execute-remote-command::show-usage
fi

APPLICATION="$1"
PHP_VERSION="${2//.}"
ENVIRONMENT="$3"
MULTIPLICITY="$4"
USER="$5"
SSH_KEYFILE="$6"
shift 6
IFS=" "
COMMAND="$*"
IFS=$'\n\t'

if [[ "${APPLICATION}" != "cron" && "${APPLICATION}" != "cron-legacy" ]] \
    || [[ "${PHP_VERSION}" != "53" && "${PHP_VERSION}" != "56" ]] \
    || [[ "${ENVIRONMENT}" != "qa" && "${ENVIRONMENT}" != "staging" ]] \
    || [[ "${MULTIPLICITY}" != "single" && "${MULTIPLICITY}" != "many" ]] \
    || [[ "${USER}" != "apache" && "${USER}" != "etl" && "${USER}" != "cronuser" ]] \
    || [ -z "${SSH_KEYFILE}" ] \
    || [ -z "${COMMAND}" ]; then
    execute-remote-command::show-usage
fi

AUTO_SCALING_GROUP="tf-${APPLICATION}-${MULTIPLICITY}-${PHP_VERSION}-${ENVIRONMENT}-asg"
INSTANCE_IP="$(execute-remote-command::get-instance-ip "${AUTO_SCALING_GROUP}")"
if [ -z "${INSTANCE_IP}" ] || [[ "${INSTANCE_IP}" = "null" ]]; then
    echo "ERROR: Couldn't find any instances for ${AUTO_SCALING_GROUP}"
    exit 1;
fi
echo "INSTANCE_IP: ${INSTANCE_IP}"

#shellcheck disable=SC2029
ssh -o StrictHostKeychecking=no -i "${SSH_KEYFILE}" "centos@${INSTANCE_IP}" sudo -u "${USER}" "${COMMAND}"