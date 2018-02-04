# CodeDeploy packaging for Succeed Legacy Cron
This code packages and deploys Succeed Legacy (for scheduled jobs) using Docker to build it, GNU Make to package it, and CodeDeploy to deploy it to AWS.

It uses GNU make to keep a zip file up to date. To ensure that the zip file is up to date, run:

   make

You can then deploy directly to AWS with:

   make deploy

## Crontab files
This deployment takes almost all of the crontab files directly from the Succeed Legacy repository, from the `succeed-legacy/build-deploy/cron/` directory. 


