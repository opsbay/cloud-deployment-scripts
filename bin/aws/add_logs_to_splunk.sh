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
#shellcheck disable=SC1090
source "$DIR/manage-splunk.sh"


# See https://aws.amazon.com/blogs/devops/using-codedeploy-environment-variables/
environment=${DEPLOYMENT_GROUP_NAME:-qa}

if manage-splunk::is_splunk_enabled "$environment" "$APP_NAME"; then 
    if ! /opt/splunkforwarder/bin/splunk status; then
        /opt/splunkforwarder/bin/splunk start
    fi
    # Just in case lets sleep to give Splunk time to start up completely
    sleep 5
    #shellcheck disable=SC2154
    manage-splunk::add_splunklogs "${log_file[@]}"
else
    if /opt/splunkforwarder/bin/splunk status; then
        /opt/splunkforwarder/bin/splunk stop
    fi
    
fi    

