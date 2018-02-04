#!/usr/bin/env bash
#
# update-dns-entries.sh
#
# Updates all the A records in Route 53 for our EC2 instances.
#
# Syntax:
#
#     update-dns-entries.sh [Route53 Zone ID]
#
# Zone ID defaults to Z2JT2J3JLGFTW6 (Hobsons dev AWS account, "mango.naviance.com.")

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
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

ROUTE53_ZONE_ID=${1:-"Z2JT2J3JLGFTW6"}

# Fetch the name for the zone we're working with.
#
# We'll need to specify it later when updating DNS records.
function update-dns-entries::get-zone-name() {
    aws route53 \
        get-hosted-zone \
        --id "${ROUTE53_ZONE_ID}" \
        | jq -r ".HostedZone.Name"
}

# Returns a list of hostnames that _should_ exist in Route53 at this moment, and IP addresses, whitespace-delimited.
function update-dns-entries::get-all-valid-hostnames() {
    # Our instance hostnames are of the following format: [auto-scaling-group-name minus the trailing "-asg"]-[instance ID].
    # i.e. an instance in the autoscaling group "tf-succeed-53-staging-asg" and with the ID "i-07419509108de2d51" will have
    # a hostname of tf-succeed-53-staging-i-07419509108de2d51
    #
    # Each instance will have a tag on it indicating the name of its auto-scaling group, so let's find them.

    # The following will:
    # 1. Fetch a list of EC2 instance names and their auto-scaling groups and IP addresses (aws)
    # 2. Format it all into a single line (jq)
    # 3. Re-arrange the text to form a valid hostname followed by IP address(sed)
    aws ec2 \
        describe-instances \
        --query "Reservations[].Instances[].[InstanceId, PrivateIpAddress, Tags[?Key=='aws:autoscaling:groupName'].Value]" \
        --filters "Name=tag:aws:autoscaling:groupName,Values=tf-*" "Name=instance-state-name,Values=running" \
        | jq -r '.[] | .[2][0] + " " + .[0] + " " + .[1]' \
        | sed -e "s/^\([^ ]\{1,\}\)-asg \(i-[0-9a-f]\{17\}\)/\1-\2/g"

    # The above sed regex could be simplified with extended regular expressions but enabling them requires the "-E"
    # parameter on BSD (e.g. OSX) and "-r" parameter on GNU (e.g. Linux) and I'd rather just go old school BRE-notation
    # than detect the OS.
}

# Returns a list of hostnames that _do_ exist in Route53 at this moment, and IP addresses, whitespace-delimited.
function update-dns-entries::get-active-hostnames() {

    # The following will:
    # 1. Fetch a JSON list of hostnames and their record types from Route 53 for a given zone (aws)
    # 2. Format it into a single line (jq)
    # 4. Cut out everything except the hostname and IP address, which we want, from the relevant lines (sed)
    #    (Each line with be of the format: [Record type] [hostname] [IP address]
    #    and the "relevant lines" are the ones that start with "A" and the hostname matches the "tf-*-i-#################"
    #    format.)
    aws route53 \
        list-resource-record-sets \
        --hosted-zone-id "${ROUTE53_ZONE_ID}" \
        --query "ResourceRecordSets[].[Name,Type,ResourceRecords[].[Value]]" \
        | jq -r '.[] | .[1] + " " + .[0] + " " + .[2][][0]' \
        | sed -n -e "s/^A \(tf-.\{1,\}-i-[0-9a-f]\{17\}\)\.[^.]\{1,\}\.naviance\.com\. \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)$/\1 \2/p"
}

# Creates the JSON to add to the bach of updates to send to Route53
function update-dns-entries::get-dns-change-json() {
    hostname="$1"
    ip_address="$2"
    action="$3"

    cat <<END_OF_JSON
        {
            "Action": "${action}",
            "ResourceRecordSet": {
                "Name": "${hostname}.${ROUTE53_ZONE_NAME}",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "${ip_address}"
                    }
                ]
            }
        }
END_OF_JSON
}

echo -n "Zone name: "
ROUTE53_ZONE_NAME="$(update-dns-entries::get-zone-name)"
echo "$ROUTE53_ZONE_NAME"

echo -n "Fetching valid hostnames... "
VALID_HOSTNAMES="$(update-dns-entries::get-all-valid-hostnames)"
echo "done."

echo -n "Fetching active hostnames... "
ACTIVE_HOSTNAMES="$(update-dns-entries::get-active-hostnames)"
echo "done."

DNS_CHANGES_JSON=""

# A variable to keep track of whether we're adding the first change to the JSON body because of JSON's stupid commas.
IS_FIRST_CHANGE=true

echo "Looking for invalid DNS records:"
# Iterate over the active hostnames and see if any exist which are not valid
for i in ${ACTIVE_HOSTNAMES}; do
    hostname="$(echo "${i}" | cut -d\  -f1)"
    ip_address="$(echo "${i}" | cut -d\  -f2)"
    if [[ "$(echo "${VALID_HOSTNAMES}" | grep "${hostname}" -c)" == "1" ]]; then
        echo "unchanged: ${hostname}.${ROUTE53_ZONE_NAME} A ${ip_address}"
        continue
    fi
    # OK. We did not find this active hostname in the list of valid hostnames.  So we want to delete it from Route53.
    echo "removing: ${hostname}.${ROUTE53_ZONE_NAME} A ${ip_address}"
    CHANGE_JSON="$(update-dns-entries::get-dns-change-json "${hostname}" "${ip_address}" DELETE)"
    if [ "${IS_FIRST_CHANGE}" = true ]; then
        DNS_CHANGES_JSON="${CHANGE_JSON}"
        IS_FIRST_CHANGE=false
    else
        DNS_CHANGES_JSON="${DNS_CHANGES_JSON},${CHANGE_JSON}"
    fi
done

echo "Looking for DNS records that need to be created:"
# Iterate over the valid hostnames and see if any of them are not active
for i in ${VALID_HOSTNAMES}; do
    hostname="$(echo "${i}" | cut -d\  -f1)"
    if [[ "$(echo "${ACTIVE_HOSTNAMES}" | grep "${hostname}" -c)" == "1" ]]; then
        echo "unchanged: ${hostname}.${ROUTE53_ZONE_NAME} A ${i}"
        continue
    fi
    # OK. We did not find this valid hostname in the list of active hostnames.  So we want to create it in Route53.
    ip_address="$(echo "${i}" | cut -d\  -f2)"
    echo "creating: ${hostname}.${ROUTE53_ZONE_NAME} A ${ip_address}"
    CHANGE_JSON=$(update-dns-entries::get-dns-change-json "${hostname}" "${ip_address}" CREATE)
    if [ "${IS_FIRST_CHANGE}" = true ]; then
        DNS_CHANGES_JSON="${CHANGE_JSON}"
        IS_FIRST_CHANGE=false
    else
        DNS_CHANGES_JSON="${DNS_CHANGES_JSON},${CHANGE_JSON}"
    fi
done

if [[ -n "$DNS_CHANGES_JSON" ]]; then 
    INPUT_JSON="$( echo "{\"Changes\": [${DNS_CHANGES_JSON}]}" | jq -c .)"

    # Submit the changes to ROUTE53. Do not keep polling to confirm they completed successfully.
    echo -n "Submitting changes to Route53, change ID: "
    CHANGE_ID="$(aws route53 \
        change-resource-record-sets \
        --hosted-zone-id "${ROUTE53_ZONE_ID}" \
        --change-batch "${INPUT_JSON}" \
        | jq -r '.ChangeInfo.Id' \
        | cut -d'/' -f3)"
    echo "${CHANGE_ID}."
else
    echo "Success: All DNS records are already in place"
fi
