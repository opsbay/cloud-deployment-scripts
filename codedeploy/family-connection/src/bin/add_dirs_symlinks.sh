#!/usr/bin/env bash

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

# Create tmp dir and download efs target info
S3_BUCKET=$(get_aws_s3_app_config_bucket)

CONFIG_DIR=$(mktemp -d)
# CONFIG_DIR_PREFIX=/tmp/efs_targets_
# CONFIG_DIR=${CONFIG_DIR_PREFIX}$(date +'%Y-%m-%d-%H-%M-%S')

# # Remove files from previous deployments
# rm -rf "${CONFIG_DIR_PREFIX}"*

aws s3 cp "s3://${S3_BUCKET}/efs/efs-mount-targets.json" "${CONFIG_DIR}/efs/"

# Assign EFS targets to vars
DOCS=$(jq -r '.edocs_mount_target.value' "${CONFIG_DIR}/efs/efs-mount-targets.json")
CLIENT_FILES=$(jq -r '.client_files_mount_target.value' "${CONFIG_DIR}/efs/efs-mount-targets.json")

if [ ! -d "${APP_DIR}/wk12/includes/hobsons" ]; then
  mkdir -p "${APP_DIR}/wk12/includes/hobsons"
fi

# NFS Mount locations
if [ ! -d /docs ]; then
  mkdir /docs
fi

if [ ! -d /httpd/client_files ]; then
  mkdir -p /httpd/client_files
fi

# Mount EFS
set +e
if ! grep -qs '/docs' /proc/mounts; then
  mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${DOCS}:/" /docs
fi
set -e

set +e
if ! grep -qs '/httpd/client_files' /proc/mounts; then
  mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 "${CLIENT_FILES}:/" /httpd/client_files
fi
set -e

WEBSERVER_USER=$(get_webserver_info user)
WEBSERVER_GROUP=$(get_webserver_info group)

# Set perms on mounts
chown -R "${WEBSERVER_USER}:${WEBSERVER_GROUP}" /docs
chown -R "${WEBSERVER_USER}:${WEBSERVER_GROUP}" /httpd/client_files

# Ensure required directories on EFS mount are present
for efs_dir in graph_cache logos photos; do \
  if [[ ! -d "/httpd/client_files/$efs_dir" ]]; then
    mkdir "/httpd/client_files/$efs_dir"
    chown -R "${WEBSERVER_USER}:${WEBSERVER_GROUP}" "/httpd/client_files/$efs_dir"
  fi

  # Comment these out until NFS shares are available
  ln -s "/httpd/client_files/$efs_dir" "$APP_DIR/wk12/$efs_dir"
done

# Ensure phperror.log exists and is writable
PHP_ERROR_LOG=/var/log/phperror.log
touch "$PHP_ERROR_LOG"
chown "${WEBSERVER_USER}" "$PHP_ERROR_LOG"
label_selinux "$PHP_ERROR_LOG"
