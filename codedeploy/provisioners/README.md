# Simple provision applications used to move legacy data to the core api services
This code packages and deploys the provisioners using GNU Make to package it and CodeDeploy to deploy it to AWS.

It uses GNU make to keep a zip file up to date. To ensure that the zip file is up to date, run:

   make clean all

You can then deploy directly to AWS with:

   make deploy

# Requirements
* JDK 1.8
* Gradle 2.9
* MySQL 5.5

# Source repository
https://github.com/naviance/naviance-core-api-provisioners
