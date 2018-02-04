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

echo 'CATALINA_OPTS="-Xms512M -Xmx512M -XX:MaxPermSize=256m"' > "${TOMCAT_HOME}/conf/conf.d/setenv.conf"
echo 'JAVA_HOME="/usr/java/default"' >> "${TOMCAT_HOME}/conf/conf.d/setenv.conf"
echo "JAVA_OPTS=\"-javaagent:${NEWRELIC_PATH}/newrelic.jar\"" >> "${TOMCAT_HOME}/conf/conf.d/setenv.conf"

chown root:tomcat "${TOMCAT_HOME}/conf/conf.d/setenv.conf"