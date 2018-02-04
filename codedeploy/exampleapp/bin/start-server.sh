#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# This is where we can set environment configuration
# for now, we just need to set an environment variable

mkdir -p /etc/exampleapp
echo "SetEnv ENV codedeploy" > /etc/exampleapp/env.conf

rm -rf /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

systemctl start nginx
systemctl start php5-fpm
