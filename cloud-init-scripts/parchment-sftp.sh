#!/usr/bin/env bash
#
# Cloud init script for parchment sftp server
#

function install_python_modules {
    # Upgrade pip
    pip install --upgrade pip
    # Install required python modules
    pip install --upgrade virtualenv boto
}

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

function get_aws_instance_id {
    id=$(try_with_backoff curl -s -m 3 http://169.254.169.254/latest/meta-data/instance-id)
    echo "${id}"
}

function get_aws_environment {
    local instanceData
    local environment
    instanceData=$(try_with_backoff aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" --region us-east-1)
    environment=$(echo "$instanceData" | jq -r '.Reservations[].Instances[].Tags[] | select(.Key=="Env") |     .Value')

    echo "${environment}"
}

function get_aws_account_id {
    local tempAccountData
    local tempAccountId

    # Figure out what account we're in use hobsons-naviancedev as a default
    tempAccountData=$(try_with_backoff curl -s -m 3 http://169.254.169.254/latest/dynamic/instance-identity/document)
    tempAccountId=$(echo "$tempAccountData" | awk -F '"' '/accountId/ { print $4 }')
    echo "${tempAccountId:-253369875794}"
}

function download_authorized_keys_from_s3 {
    local s3bucket
    local user

    # Set s3bucket name and file location
    s3bucket="unmanaged-app-config-${1}"
    user=${2}
    userhome=$(getent passwd "${user}" | cut -d ":" -f 6)
    mkdir -p         "${userhome}/.ssh"
    chown "${user}." "${userhome}/.ssh"
    chmod go-rwx     "${userhome}/.ssh"
    try_with_backoff aws s3 cp "s3://${s3bucket}/parchment-sftp/${user}-authorized-keys" "${userhome}/.ssh/authorized_keys" 2>&1 | logger -t parchment-sftp-cloud-init
    chown "${user}." "${userhome}/.ssh/authorized_keys"
    chmod go-rwx     "${userhome}/.ssh/authorized_keys"
}

function add_user {
    user=$1
    password=$2
    adduser -b "/sftp" "$user"
    if [ -n "$password" ] ; then
        echo "$user:$password" | chpasswd
    # else no password to set
    fi
}

# "qa"         -> "eipalloc-0bb1a73b"
# "production" -> "eipalloc-048a9c34"
function set_elastic_ip_address {
    local instanceid
    local s3bucket

    instanceid="${1}"
    # Set s3bucket name and file location
    s3bucket="unmanaged-app-config-${2}"

    try_with_backoff aws s3 cp "s3://${s3bucket}/parchment-sftp/elastic-ip-address" "/tmp/elastic-ip-address" 2>&1 | logger -t parchment-sftp-cloud-init
    ALLOCATION_ID=$(cat /tmp/elastic-ip-address)
    if [ ! -z "$ALLOCATION_ID" ]; then
        try_with_backoff aws ec2 associate-address --instance-id "${instanceid}" --allocation-id "${ALLOCATION_ID}" --region us-east-1 2>&1 | logger -t parchment-sftp-cloud-init
    fi
}

function ssh_config {
    local instanceid
    local s3bucket
    local app_name
    local filename
    local s3_file_url

    instanceid="${1}"
    # Set s3bucket name and file location
    s3bucket="unmanaged-app-config-${2}"
    app_name="${3}"
    filename="etcsshhostkeys.tar.gz"
    s3_file_url="s3://${s3bucket}/${app_name}/${filename}"
    # Configure Parchment SFTP SSH keys
    echo "ssh_config: testing aws s3 ls ${s3_file_url}"
    if aws s3 ls "${s3_file_url}" ; then
        echo "Downloading SSH key and hosts file for Parchment"
        aws s3 cp "${s3_file_url}" "/tmp/${filename}"
        # etcsshhostkeys.tar.gz has the complete path, so exploding it from root dir
        #shellcheck disable=SC2164
        cd / ; tar -xvzf "/tmp/${filename}"
        chown root.  /etc/ssh/ssh_host*
        chmod go-rwx /etc/ssh/ssh_host*
        chmod a+r    /etc/ssh/ssh_host*.pub
    fi
}

function setup_hosts_allow {
    # Setup hosts.allow as a mirror of the security group
    cat > "/etc/hosts.allow" << EOF
# hosts.allow   This file contains access rules which are used to
#       allow or deny connections to network services that
#       either use the tcp_wrappers library or that have been
#       started through a tcp_wrappers-enabled xinetd.
#
#       See 'man 5 hosts_options' and 'man 5 hosts_access'
#       for information on rule syntax.
#       See 'man tcpd' for information on tcp_wrappers
#
ALL: 10.0.0.0/255.0.0.0, 172.16.0.0/255.240.0.0, 192.168.0.0/255.255.0.0

# conversion from CIDR to masks according to https://www.oav.net/mirrors/cidr.html
ALL: 10.32.102.0/255.255.255.128
ALL: 96.46.148.248/255.255.255.252
ALL: 96.46.148.252/255.255.255.252
ALL: 96.46.150.232/255.255.255.252
ALL: 96.46.159.128/255.255.255.224

# 204.108.64.1 - 204.108.127.255 range
ALL: 204.108.64.1/255.255.255.255
ALL: 204.108.64.2/255.255.255.254
ALL: 204.108.64.4/255.255.255.252
ALL: 204.108.64.8/255.255.255.248
ALL: 204.108.64.16/255.255.255.240
ALL: 204.108.64.32/255.255.255.224
ALL: 204.108.64.64/255.255.255.192
ALL: 204.108.64.128/255.255.255.128
ALL: 204.108.65.0/255.255.255.0
ALL: 204.108.66.0/255.255.254.0
ALL: 204.108.68.0/255.255.252.0
ALL: 204.108.72.0/255.255.248.0
ALL: 204.108.80.0/255.255.240.0
ALL: 204.108.96.0/255.255.240.0
ALL: 204.108.112.0/255.255.248.0
ALL: 204.108.120.0/255.255.252.0
ALL: 204.108.124.0/255.255.254.0
ALL: 204.108.126.0/255.255.255.0
ALL: 204.108.127.0/255.255.255.128
ALL: 204.108.127.128/255.255.255.192
ALL: 204.108.127.192/255.255.255.224
ALL: 204.108.127.224/255.255.255.240
ALL: 204.108.127.240/255.255.255.248
ALL: 204.108.127.248/255.255.255.252
ALL: 204.108.127.252/255.255.255.254
ALL: 204.108.127.254/255.255.255.255
ALL: 204.108.127.255/255.255.255.255

# bastion ssh permitted ips
ALL: 4.14.235.30/255.255.255.255
ALL: 66.161.171.254/255.255.255.255
ALL: 194.168.123.98/255.255.255.255
ALL: 203.87.62.226/255.255.255.255
EOF
}

function mount_efs {
    local account_id
    local s3bucket
    local config_dir
    local mount_point
    local parchment_sftp
    local json_file

    account_id="${1}"
    s3bucket="unmanaged-app-config-${account_id}"
    config_dir="/tmp"
    mount_point="/sftp"
    json_file="efs-mount-targets.json"

    aws s3 cp "s3://${s3bucket}/efs/${json_file}" "${config_dir}/"
    parchment_sftp=$(jq -r '.parchment_sftp_mount_target.value' "${config_dir}/${json_file}")

    # NFS mount location
    if [[ ! -d "${mount_point}" ]]; then
      mkdir -p "${mount_point}"
    fi

    # mount EFS
    grep -qs "${mount_point}" /proc/mounts
    RC=$?
    if [[ $RC != 0 ]]; then
      mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${parchment_sftp}:/" "${mount_point}"
    fi
}

INSTANCE_ID=$(get_aws_instance_id)
ACCOUNT_ID=$(get_aws_account_id)
APP_NAME="parchment-sftp"

mount_efs "$ACCOUNT_ID"
add_user "parchment"
add_user "launified"

# <temp request> from kevin & co
add_user "commonapp"
download_authorized_keys_from_s3 "$ACCOUNT_ID" "commonapp"
# we are still missing the whitelisted ip address.
# </temp request>

download_authorized_keys_from_s3 "$ACCOUNT_ID" "parchment"
download_authorized_keys_from_s3 "$ACCOUNT_ID" "launified"
set_elastic_ip_address "$INSTANCE_ID" "$ACCOUNT_ID"
ssh_config "$INSTANCE_ID" "$ACCOUNT_ID" "$APP_NAME"
setup_hosts_allow
