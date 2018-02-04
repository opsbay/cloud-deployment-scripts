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

AWS_DEFAULT_REGION=$(get_aws_region)
export AWS_DEFAULT_REGION

# Thanks Stack Overflow https://stackoverflow.com/a/40121084/424301
AWS_ACCOUNT_ID=$(get_aws_account_id)
bucket="s3://unmanaged-app-config-${AWS_ACCOUNT_ID}"

# See https://aws.amazon.com/blogs/devops/using-codedeploy-environment-variables/
environment=${DEPLOYMENT_GROUP_NAME:-qa}
APP_DIR="${APP_DIR}"
SSH_DIR="/home/$APP_USER/.ssh"

aws s3 cp "$bucket/${environment}/${APP_NAME}/aspose.words.lic" "$APP_DIR"
aws s3 cp "$bucket/${environment}/${APP_NAME}/${APP_NODE}-bootstrap.properties" "$APP_DIR"
ln -s "$APP_DIR/${APP_NODE}-bootstrap.properties" "$APP_DIR/bootstrap.properties"

# NAWS-968 Configure Parchment SFTP SSH keys
if aws s3 ls "$bucket/${environment}/${APP_NAME}/ssh_key_parchment" && \
    aws s3 ls "$bucket/${environment}/${APP_NAME}/ssh_known_hosts"; then
    if [[ "$APP_NODE" = "edocssub" ]] || [[ "$APP_NODE" = "edocssubp" ]]; then
        echo "Downloading SSH key and hosts file for Parchment"
        aws s3 cp "$bucket/${environment}/${APP_NAME}/ssh_key_parchment" "$SSH_DIR/id_rsa"
        aws s3 cp "$bucket/${environment}/${APP_NAME}/ssh_known_hosts" "$SSH_DIR/known_hosts"
        chown -R "$APP_USER:$APP_USER" "$SSH_DIR"
        chmod -R go-rwx "$SSH_DIR"
    fi
fi

