# CodeDeploy packaging for Succeed
This code packages and deploys Succeed using Docker to build it, GNU Make to package it, and CodeDeploy to deploy it to AWS.

It uses GNU make to keep a zip file up to date. To ensure that the zip file is up to date, run:

   make

You can then deploy directly to AWS with:

   make deploy

##  This is doing NJQ code deployment
this will use crontab command line scrips to change the cron jobs



