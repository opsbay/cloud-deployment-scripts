# Placeholder Application for CodeDeploy
This placeholder app is intended to be a small, easily understood example of a CodeDeploy application that works with the Terraform and Packer installation. It has both an HTML `index.html` file and a `phpinfo.php` file that can be used to test whether PHP is working.

It uses GNU make to keep a pair of zip files that Terraform is responsible for deploying up to date. To ensure that the zip files are up to date, run:

   make


## Customizing this for another app

* Copy these files to a new app
* Replace the application name `APP_NAME` (set to _placeholder_ for this sample) in `Makefile`
