# Naviance BIRT Reporting Tool
This code packages and deploys Naviance Brit using GNU Make to package it and CodeDeploy to deploy it to AWS.

It uses GNU make to keep a zip file up to date. To ensure that the zip file is up to date, run:

   make clean all

You can then deploy directly to AWS with:

   make deploy

