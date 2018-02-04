#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# Removed -e option because it would cause the script to exit if a grep failed
set -uo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

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

# Ensure phperror.log exists
touch /var/log/phperror.log
chown apache /var/log/phperror.log
