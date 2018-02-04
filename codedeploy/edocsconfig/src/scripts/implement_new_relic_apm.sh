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
newrelic_dir="$APP_DIR/newrelic"

#exporting the bucket names
bucket=$(get_aws_s3_app_config_bucket)
s3_config_dir="$APP_CONFIG_DIR/s3"

# extracting the licence key from s3 bucket
rm -rf "${s3_config_dir}/newrelic"
mkdir -p "${s3_config_dir}/newrelic"
newrelic_licence="${s3_config_dir}/newrelic/newrelic-licence.txt"
aws s3 cp "s3://$bucket/newrelic/newrelic-license.txt" "$newrelic_licence"
licence_key=$(grep NEW_RELIC_KEY "${s3_config_dir}/newrelic/newrelic-licence.txt" | awk -F '=' '{print $2}')

# Configure New Relic sysmond
nrsysmond-config --set license_key="$licence_key"
service newrelic-sysmond restart

# Configure New Relic
unzip "$DIR/$newrelic_zip" -d "$APP_DIR"
mkdir -p "$newrelic_dir/logs"
chmod 750 "$newrelic_dir/"
chmod 640 "$newrelic_dir/"*
chmod 770 "$newrelic_dir/logs"
sed -i.bak "
    s/<%= license_key %>/$licence_key/;
    s/app_name: .*/app_name: $newrelic_app_name/" \
    "$newrelic_dir/newrelic.yml"
chown -R "root:$SERVER_USER" "$newrelic_dir"

