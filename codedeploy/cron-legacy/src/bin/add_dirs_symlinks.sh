#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# Removed -e option because it would cause the script to exit if a grep failed
set -uo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
source "$DIR/common.sh"

# Create tmp dir and download efs target info
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.accountId')
S3_BUCKET=unmanaged-app-config-${ACCOUNT_ID}

CONFIG_DIR_PREFIX=/tmp/efs_targets_
CONFIG_DIR=${CONFIG_DIR_PREFIX}$(date +'%Y-%m-%d-%H-%M-%S')

# Remove files from previous deployments
rm -rf "${CONFIG_DIR_PREFIX}"*

aws s3 cp "s3://${S3_BUCKET}/efs/efs-mount-targets.json" "${CONFIG_DIR}/efs/"

# Assign EFS targets to vars
DOCS=$(jq -r '.edocs_mount_target.value' "${CONFIG_DIR}/efs/efs-mount-targets.json")
CLIENT_FILES=$(jq -r '.client_files_mount_target.value' "${CONFIG_DIR}/efs/efs-mount-targets.json")

if [ ! -d /httpd/k12/wk12/includes/hobsons ]; then
  mkdir -p /httpd/k12/wk12/includes/hobsons
fi

# NFS Mount locations

if [ ! -d /docs ]; then
  mkdir /docs
fi

if [ ! -d /httpd/client_files ]; then
  mkdir -p /httpd/client_files
fi

# Mount EFS

grep -qs '/docs' /proc/mounts
RC=$?

if [ $RC != 0 ]; then
  mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${DOCS}:/" /docs
fi

grep -qs '/httpd/client_files' /proc/mounts
RC=$?

if [ $RC != 0 ]; then
  mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${CLIENT_FILES}:/" /httpd/client_files
fi

# Set perms on mounts
chown apache:apache /docs
chown apache:apache /httpd/client_files

# Ensure required directories on EFS mount are present
if [ ! -d /httpd/client_files/graph_cache ]; then
  mkdir /httpd/client_files/graph_cache
  chown apache:apache /httpd/client_files/graph_cache
fi

if [ ! -d /httpd/client_files/logos ]; then
  mkdir /httpd/client_files/logos
  chown apache:apache /httpd/client_files/logos
fi

if [ ! -d /httpd/client_files/photos ]; then
  mkdir /httpd/client_files/photos
  chown apache:apache /httpd/client_files/photos
fi

# Comment these out until NFS shares are available
ln -s /httpd/client_files/graph_cache /httpd/k12/wk12/graph_cache
ln -s /httpd/client_files/logos /httpd/k12/wk12/logos
ln -s /httpd/client_files/photos /httpd/k12/wk12/photos

# define WEBSERVER_USER and _GROUP
WEBSERVER_USER=$(get_webserver_info user)
#WEBSERVER_GROUP=$(get_webserver_info group)

# Ensure phperror.log exists and is writable
PHP_ERROR_LOG=/var/log/phperror.log
touch "$PHP_ERROR_LOG"
chown "${WEBSERVER_USER}" "$PHP_ERROR_LOG"
enable_selinux_writes "$PHP_ERROR_LOG"
