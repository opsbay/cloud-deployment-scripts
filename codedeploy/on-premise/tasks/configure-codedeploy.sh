#!/usr/bin/env bash

# This file depends on create-user.sh for:
#  1. $cd_user_access_key
#  2. $cd_user_secret_key
#  3. $cd_user_arn

Out.blue "Running: ${BASH_SOURCE[0]}"

DIR="$BASEDIR/tasks"


# TODO: Only do this if '$cd_user_secret_key' is empty
# TODO: See: tasks/create-user.sh

Out.blue "Setting up the CodeDeploy config file."
cp -f "$DIR/../codedeploy.onpremises.yml" /tmp/codedeploy.onpremises.yml
#shellcheck disable=SC2154
sed -i.bak -e "s/{{ AWS_ACCESS_KEY_ID }}/${cd_user_access_key}/g" /tmp/codedeploy.onpremises.yml
#shellcheck disable=SC2154
sed -i.bak -e "s@{{ AWS_SECRET_ACCESS_KEY }}@${cd_user_secret_key}@g" /tmp/codedeploy.onpremises.yml
#shellcheck disable=SC2154
sed -i.bak -e "s@{{ IAM_USER_ARN }}@${cd_user_arn}@g" /tmp/codedeploy.onpremises.yml

aws_default_region=$(aws configure get default.region)
sed -i.bak -e "s/{{ AWS_DEFAULT_REGION }}/$aws_default_region/g" /tmp/codedeploy.onpremises.yml

mkdir -p /etc/codedeploy-agent/conf
sudo cp -f /tmp/codedeploy.onpremises.yml /etc/codedeploy-agent/conf/codedeploy.onpremises.yml
rm -f /tmp/codedeploy.onpremises.yml.bak

Out.green "Config file created at /etc/codedeploy-agent/conf/codedeploy.onpremises.yml"
