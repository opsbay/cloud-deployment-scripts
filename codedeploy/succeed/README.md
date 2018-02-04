# CodeDeploy packaging for Succeed
This code packages and deploys Succeed using Docker to build it, GNU Make to package it, and CodeDeploy to deploy it to AWS.

It uses GNU make to keep a zip file up to date. To ensure that the zip file is up to date, run:

   make

You can then deploy directly to AWS with:

   make deploy

## Apache HTTPD configuration files
This deployment takes almost all of the Apache configuration files directly from the Succeed repository, from the `succeed/build-deploy/httpd.conf` directory. The sole exception is `httpd.conf` which is generated from `etc/httpd.conf.j2` by this download process.

## PHP console actions in deployment
Some of the scripts in the `src/bin` directory do things like warm cache (among other things) using Symfony's console. Whether this works fully should be tested now that we have more than a sample application deployed.


