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

#exporting the bucket names
bucket=$(get_aws_s3_app_config_bucket)
s3_config_dir="$APP_CONFIG_DIR/s3"

# extracting the licance key from s3 bucket
rm -rf "${s3_config_dir}/newrelic"
mkdir -p "${s3_config_dir}/newrelic"
newrelic_licence="${s3_config_dir}/newrelic/newrelic-license.txt"
aws s3 cp "s3://$bucket/newrelic/newrelic-license.txt" "$newrelic_licence"
licence_key=$(grep NEW_RELIC_KEY "${s3_config_dir}/newrelic/newrelic-license.txt" | awk -F '=' '{print $2}')

NEWRELIC_RPM=newrelic-php5
if rpm -q "$NEWRELIC_RPM"; then
    echo "$NEWRELIC_RPM already installed"
else
    yum install -q -y "$NEWRELIC_RPM"
fi

# Create this before newrelic-install is run for the
# first time so that it runs the version of the newrelic-daemon
# that references this config file when it starts up
socket_file="/var/run/newrelic/.newrelic.sock"
echo "port=\"$socket_file\"" > /etc/newrelic/newrelic.cfg

# FIXME: use interactive install with here document
# Surely there has to be a command line switch way of doing this...
newrelic-install <<EOF
1
$licence_key
2
EOF

newrelic_app_name="Naviance_${APP_NAME}_${INSTALLED_PHP_VERSION}_${DEPLOYMENT_GROUP_NAME}"
sed -i.bak \
    -e 's/^newrelic.appname =.*/newrelic.appname = "'"$newrelic_app_name"'"/' \
    /etc/php.d/newrelic.ini
sed -i.bak \
    -e "s|^.*newrelic.daemon.port =.*|newrelic.daemon.port = \"$socket_file\"|" \
    /etc/php.d/newrelic.ini

nrsysmond-config --set license_key="$licence_key"
service newrelic-sysmond restart
service newrelic-daemon stop
# We need to sleep to give NewRelic a chance to breathe.
sleep 10
service newrelic-daemon start

# Giving NewRelic time to actually create the socket file before we work our SELinux magic.
while [[ ! -S "$socket_file" ]]; do
    sleep 1
done

