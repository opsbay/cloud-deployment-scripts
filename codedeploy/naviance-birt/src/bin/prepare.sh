#!/bin/bash

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

for each_dir in "${TOMCAT_HOME}/webapps" "${TOMCAT_HOME}/logs"; do \
    if [ -d "${each_dir}" ] ; then
      rm -rf "${each_dir}"/*
    fi
done

if [ -d "${NEWRELIC_PATH}" ] ; then
    rm -rf "${NEWRELIC_PATH}"
fi

if [ -f "${TOMCAT_HOME}/conf/conf.d/setenv.conf" ] ; then
  rm "${TOMCAT_HOME}/conf/conf.d/setenv.conf"
fi

firewall-cmd --add-port="$APP_PORT/tcp" --permanent
firewall-cmd --reload