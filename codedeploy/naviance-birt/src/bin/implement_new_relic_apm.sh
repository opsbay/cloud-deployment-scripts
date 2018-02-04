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

newrelic_zip="newrelic-java-3.42.0.zip"
# See https://aws.amazon.com/blogs/devops/using-codedeploy-environment-variables/
newrelic_app_name="Naviance_${APP_NAME}_${DEPLOYMENT_GROUP_NAME}"

#exporting the bucket names
bucket=$(get_aws_s3_app_config_bucket)
s3_config_dir="$APP_CONFIG_DIR/s3"

# extracting the licence key from s3 bucket
if [ -d "${s3_config_dir}/newrelic" ] ; then
  rm -rf "${s3_config_dir}/newrelic"
fi
mkdir -p "${s3_config_dir}/newrelic"
newrelic_licence="${s3_config_dir}/newrelic/newrelic-licence.txt"
aws s3 cp "s3://$bucket/newrelic/newrelic-license.txt" "$newrelic_licence"
licence_key=$(grep NEW_RELIC_KEY "${s3_config_dir}/newrelic/newrelic-licence.txt" | awk -F '=' '{print $2}')

# Configure New Relic sysmond
nrsysmond-config --set license_key="$licence_key"
service newrelic-sysmond restart

# Configure New Relic
unzip "$DIR/$newrelic_zip" -d "$TOMCAT_HOME"
mkdir -p "$NEWRELIC_PATH/logs"
chmod 0750 "$NEWRELIC_PATH/"
chmod 0640 "$NEWRELIC_PATH/"*
chmod 0770 "$NEWRELIC_PATH/logs"
sed -i.bak "
    s/<%= license_key %>/$licence_key/;
    s/app_name: .*/app_name: $newrelic_app_name/" \
    "$NEWRELIC_PATH/newrelic.yml"
chown -R "root:tomcat" "$NEWRELIC_PATH"

