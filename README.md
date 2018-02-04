# Deployment Scripts

Deployment scripts for AWS, Jenkins, Terraform, Packer and friends. See [Packer Readme](packer/README.md) for more information about the ongoing effort to standardize AMI builds.

## Running the scripts

You can run these from your local environment although in the long run we will probably run these exclusively from Jenkins.

### Tools
To get started you have to have a few tools set up:

* [AWS Account](https://aws.amazon.com/)
* [AWS CLI Tools](https://aws.amazon.com/cli/)
* [Packer](https://www.packer.io/)
* [Docker](https://www.docker.com/)
* [Terraform](https://www.terraform.io/)
* [jq](https://stedolan.github.io/jq/)
* [shellcheck](http://www.shellcheck.net/)

If you are running on Mac OS X, these commands will set up your environment:

    # Install Homebrew if you have not already
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

    # Install Packer, Terraform, shellcheck, and jq using Homebrew
    brew install packer terraform jq

    pip install --upgrade --user awscli

In addition, you may be able to modify the Ansible scripts used in Packer and the CodeDeploy scripts used for provisioning more quickly if you set up a local development environment. This has support for using Vagrant and VirtualBox to help with that, you will also need to install these packages (use the vendor packaging):

* [Docker](https://www.docker.com/) (version 17.03.1-ce or higher)
* [Vagrant](https://www.vagrantup.com/) (version 1.9.1 or higher)
* [Virtualbox](https://www.vagrantup.com/) (version 5.1.14 or higher)

### Environment Variables
You should source an environment file before running the packer and terraform commands that specify the AWS profile, region, and VPC constants for the Packer build.

A [sample file](env.sh.sample) is provided as a template to customize:

```
cp env.sh.sample env.sh
vim env.sh
. env.sh
```
Many of the scripts source this `env.sh` file so please be sure it is present when working with the project.

### Linting
This supports linting the sources. The entry point for that is running `make` in the top level directory.

Linters currently implemented include:

* shellcheck

Linters we could add include:

* tflint
* a json linter
* a yaml linter
* https://github.com/willthames/ansible-lint


## On Premise Deployments

### Setting up

Because of the conventions used, one of the files our apps (such as succeed, etc) require, such as as parameters.yml.j2, in succeed, must exist in an S3 bucket like `s3://unmanaged-app-config-AWS_ACCOUNT_ID/AWS_USERNAME/succeed/app/parameters.yml.j2`.
For this reason, every developer must create a duplicate of the app configs S3 bucket using their username.

This is the easiest way to do it:
```
# Pull existing configs
$ bin/configs.sh pull
Sourcing /Users/richard/Documents/Hobsons/cloud-deployment-scripts/bin/../env.sh
Targeting region us-east-1 in AWS Account 253369875794

# Create a dir with your AWS username in the path in for the form 'build/configs/AWS_USERNAME/succeed'
$ mkdir -p build/configs/richard/succeed

# Sync (copy) over your configs
$ rsync -a build/configs/qa/succeed/ build/configs/richard/succeed/

# Push your configs up. Since your dir was just added, it will be created on S3.
$ bin/configs.sh push
Sourcing /Users/richard/Documents/Hobsons/cloud-deployment-scripts/bin/../env.sh
Targeting region us-east-1 in AWS Account 253369875794
upload: build/configs/richard/succeed/php/php.ini.j2 to s3://unmanaged-app-config-253369875794/richard/succeed/php/php.ini.j2
upload: build/configs/richard/succeed/app/parameters.yml.j2 to s3://unmanaged-app-config-253369875794/richard/succeed/app/parameters.yml.j2
```

### Workflow

Run all commands from the root of the repo (where Vagrantfile exists).

This will bring up your Vagrant machine, install Ansible, run the roles defined in site.yml and then configure the on-premise deployment users, instances, policies, etc:
```
vagrant up
```
At the end of the output of the above command, a check script will run that will verify if the settings are as expected so look for any errors at that point.

Once you are done, you can stop your Vagrant machine, if you want:
```
vagrant halt
```

If you want to rebuild your Vagrant machine (including the on-premise setup), then you must first destroy it:
```
vagrant destroy
```
The destroy runs a hook via the `vagrant-triggers` plug-in. This hook will remove the CodeDeploy on-premise user among other things. Simply running `vagrant reload --provision` will not destroy the user and may cause unexpected behaviour.
Instead of destroying the machine, if all you want to do is re-setup your CodeDeploy setup, SSH into the vagrant machine and run this:
```
/vagrant/codedeploy/on-premise/setup.sh down
/vagrant/codedeploy/on-premise/setup.sh up
```
That will remove some parts of the CodeDeploy setup and re-setup the entire thing again.


# Acknowldgements

The original authors of this set of scripts were Matt McCants <matt@moduscreate.com> and Richard Bullington-McGuire <richard@moduscreate.com>.

# Legal

Copyright © 2017 Hobsons. All rights reserved.

This work is based in part on an authorized technology transfer to Hobsons from DMGT sister company Environmental Data Resources, Inc. This code came from an [EDR repository](https://github.com/EDRInc/Platform-Deploy-Scripts) from the git commits `ae2b13ac166bb0f428066575aa540906aa996f20` and `1a93b470c0eeb46de04f25f2e9aff9aae94814de` and went
through a sanitization process to remove EDR-specific IDs, networks, application names, etc.

This portion of the work is used with permission, and bears this copyright notice:

Copyright © 2017 Environmental Data Resources, Inc.

Parts of the VPC Module contained within this work were derived and inspired by work from a community module [tf_aws_vpc](https://github.com/terraform-community-modules/tf_aws_vpc) which is licensed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

