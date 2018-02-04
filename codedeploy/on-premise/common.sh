#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

#
# TODO: This is not necessary but removing it might cause breakage. Test this.
#
# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
#shellcheck disable=SC2034
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Taken from Sheldon: https://github.com/housni/Sheldon
Out.red() {
    local before
    local after

    before="\033[31m"
    after="\033[0m"

    echo -e "${before}$1${after}\n"
}

# Out.green "My green bold text"
Out.green() {
    local before
    local after

    before="\033[32m"
    after="\033[0m"

    echo -e "${before}$1${after}\n"
}

# Out.blue "My blue bold text"
Out.blue() {
    local before
    local after

    before='\033[34m'
    after='\033[0m'

    echo -e "${before}$1${after}\n"
}

# Get the first part of the AWS users name, separated by '@'.
# For example, if the user name is 'foo.bar@moduscreate.com', 'aws_user' will be 'foo.bar'
aws_user="$(aws iam get-user --query 'User'.UserName --output text | cut -d@ -f 1)"

# CodeDeploys IAM users name.
#shellcheck disable=SC2034
username="unmanaged-cd-$aws_user"

# CodeDeploys role name.
#shellcheck disable=SC2034
role_name="CodeDeployServiceRole"

#shellcheck disable=SC2034
app_name="unmanaged-onpremise"

# If we change this value here, we must change the 'get_aws_region' and the 'get_aws_account_id'
# function in the common.sh files of all our apps because that function determines the type of
# instance (on-premise, etc) based on the value of the deployment_group variable, below.
# See: https://aws.amazon.com/blogs/devops/using-codedeploy-environment-variables/
#shellcheck disable=SC2034
deployment_group="$aws_user"

#shellcheck disable=SC2034
instance_tag="codedeploy-onprem-$aws_user"

#shellcheck disable=SC2034
instance_name="codedeploy-onprem-instance-$aws_user"

#shellcheck disable=SC2034
policy_name="CodeDeploy-OnPrem-Permissions"
