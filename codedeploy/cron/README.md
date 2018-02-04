# CodeDeploy packaging for Succeed Cron
This code packages and deploys Succeed (for scheduled jobs) using Docker to build it, GNU Make to package it, and CodeDeploy to deploy it to AWS.

It uses GNU make to keep a zip file up to date. To ensure that the zip file is up to date, run:

   make

You can then deploy directly to AWS with:

   make deploy

## Crontab files
This deployment takes almost all of the crontab files directly from the Succeed repository, from the `succeed/build-deploy/cron/` directory. 

## PHP console actions in deployment
Some of the scripts in the `src/bin` directory do things like warm cache (among other things) using Symfony's console. Whether this works fully should be tested now that we have more than a sample application deployed.


