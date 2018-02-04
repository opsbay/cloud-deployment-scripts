#!/usr/bin/env bash
#
# Cloud init script for install a logic monitor collector
#
# References:
# https://www.logicmonitor.com/support/rest-api-developers-guide/overview/using-logicmonitors-rest-api/#Authentication_1
# https://www.logicmonitor.com/support/getting-started/i-just-signed-up-for-logicmonitor-now-what/3-adding-collectors/#Installing-a-Linux-Collector
# https://www.logicmonitor.com/support/rest-api-developers-guide/collectors/downloading-a-collector-installer/
# https://www.logicmonitor.com/support/rest-api-developers-guide/collectors/add-a-collector/
###############################################################################
# Global default values
###############################################################################

# Logic monitor credentials
LM_ACCESS_ID="Some id"
LM_ACCESS_KEY="Some key"

# Company target
COMPANY='hobsons'

# Lates version of the collector
# https://www.logicmonitor.com/support/settings/collectors/collector-versions/
COLLECTOR_VERSION="24002"

# Collectors ID, it should be created before deploying this server
COLLECTOR_ID=""

###############################################################################
# Utility funcions
###############################################################################

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

function get_aws_account_id {
    local tempAccountData
    local tempAccountId

    # Figure out what account we're in use hobsons-naviancedev as a default
    tempAccountData=$(try_with_backoff curl -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document)
    tempAccountId=$(echo "$tempAccountData" | awk -F '"' '/accountId/ { print $4 }')
    echo "${tempAccountId:-253369875794}"
}

function download_logicmonitor_credentials_from_s3 {
    local s3bucket
    local tempfile

    # Set s3bucket name and file location
    s3bucket="unmanaged-app-config-${1}"

    # Download the tenable key in a temporary file
    tempfile=$(mktemp)
    try_with_backoff aws s3 cp "s3://${s3bucket}/logicmonitor/logicmonitor.json" "$tempfile" 2>&1 | logger -t logicmonitor-cloud-init

    # Save it in the global var and remove the temp file
    #shellcheck disable=SC1090
    LM_ACCESS_ID=$(grep LM_ACCESS_ID "$tempfile" | awk -F '"' '{print $4}')
    LM_ACCESS_KEY=$(grep LM_ACCESS_KEY "$tempfile" | awk -F '"' '{print $4}')
    COMPANY=$(grep COMPANY "$tempfile" | awk -F '"' '{print $4}')
    COLLECTOR_VERSION=$(grep COLLECTOR_VERSION "$tempfile" | awk -F '"' '{print $4}')
    COLLECTOR_ID=$(grep COLLECTOR_ID "$tempfile" | awk -F '"' '{print $4}')
    rm -f "$tempfile"
}

function download_logicmonitor_installer {
    local lm_access_id
    local lm_access_key
    local company
    local collector_id
    local collector_version
    local bin_destination

    lm_access_id="$1"
    lm_access_key="$2"
    company="$3"
    collector_id="$4"
    collector_version="$5"
    bin_destination="$6"
 
    # Ensure the dir exists
    mkdir -p /opt/logicmonitor/

cat << EOF > /opt/logicmonitor/bin_downloader.py
#!/bin/env python

import requests
import json
import hashlib
import base64
import time
import hmac

#Account Info
AccessId = '$lm_access_id'
AccessKey = '$lm_access_key'
Company = '$company'

#Request Info
httpVerb ='GET'
resourcePath = '/setting/collectors/$collector_id/installers/Linux64'
queryParams = '?collectorVersion=$collector_version'
data = ''

#Construct URL
url = 'https://'+ Company +'.logicmonitor.com/santaba/rest' + resourcePath +queryParams

#Get current time in milliseconds
epoch = str(int(time.time() * 1000))

#Concatenate Request details
requestVars = httpVerb + epoch + data + resourcePath

#Construct signature
signature = base64.b64encode(hmac.new(AccessKey,msg=requestVars,digestmod=hashlib.sha256).hexdigest())

#Construct headers
auth = 'LMv1 ' + AccessId + ':' + signature + ':' + epoch
headers = {'Content-Type':'application/json','Authorization':auth}

#Make request
response = requests.get(url, data=data, headers=headers)

#Print status and write body of response to a file
print 'Response Status:',response.status_code
file_ = open('$bin_destination', 'w')
file_.write(response.content)
file_.close()
EOF

    # Set proper permissions
    chmod 700 /opt/logicmonitor/bin_downloader.py
    /opt/logicmonitor/bin_downloader.py
    chmod u+x "$bin_destination"
}

###############################################################################

# 1) Download the account id and key from s3 bucket (Taylor is on it)
ACCOUNT_ID=$(get_aws_account_id)
download_logicmonitor_credentials_from_s3 "$ACCOUNT_ID"

# 2) Download the binary for the new collector registered in previous step
#    Reference: https://www.logicmonitor.com/support/rest-api-developers-guide/collectors/downloading-a-collector-installer/
download_logicmonitor_installer \
    "$LM_ACCESS_ID"             \
    "$LM_ACCESS_KEY"            \
    "$COMPANY"                  \
    "$COLLECTOR_ID"             \
    "$COLLECTOR_VERSION"        \
    /opt/logicmonitor/LogicMonitorSetup.bin

# 3) Install logic monitor collector
/opt/logicmonitor/LogicMonitorSetup.bin

# 4) Some times, the services logicmonitor-agent and logicmonitor-watchdog are not started. This ensures its started
sleep 20
systemctl start logicmonitor-agent.service
systemctl start logicmonitor-watchdog.service
