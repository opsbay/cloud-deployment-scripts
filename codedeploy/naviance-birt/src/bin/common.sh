#!/usr/bin/env bash

# USed by bin/aws/add_logs_to_splunk.sh
declare APP_NAME
declare APP_PORT
declare TOMCAT_HOME
declare TOMCAT_TEMP
declare log_file
declare APP_CONFIG_DIR
declare NEWRELIC_PATH

# shellcheck disable=SC2034
APP_NAME="{{ APP_NAME }}"
# shellcheck disable=SC2034
APP_PORT=8080
TOMCAT_HOME="/usr/share/tomcat"
TOMCAT_TEMP="${TOMCAT_HOME}/temp"
# shellcheck disable=SC2034
APP_CONFIG_DIR="${TOMCAT_TEMP}/etc"
NEWRELIC_PATH="${TOMCAT_HOME}/newrelic"
# Splunk variables
log_file=( "${TOMCAT_HOME}/logs/*" "${NEWRELIC_PATH}/logs/*" )

export log_file

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$DIR/manage-aws.sh"