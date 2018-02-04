#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

chown -R www-data:www-data /opt/exampleapp

# It is better to do this in the baking step..
pushd /var/exampleapp
  /usr/local/bin/composer -q install
popd

chown -R www-data:www-data /opt/exampleapp
touch /var/log/codedeploy_exampleapp.log
chown -R www-data:www-data /var/log/codedeploy_exampleapp.log
