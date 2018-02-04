#!/usr/bin/env bash
#
# Generates and/or installs a JSON file containing a bucket policy granting access to our codedeploy IAM prod roles
#
# Syntax:
#
#     manage-codedeploy-permissions.sh [generate|install] [bucketname] [filename]
#
# Examples:
#
#   # Generate the JSON file containing the bucket policy.
#   bin/manage-codedeploy-permissions.sh generate > bucketpolicy.json
#
#   # Install the JSON file containing the policy to the bucket. (You should have the dev env.sh in place for this stage.)
#   bin/manage-codedeploy-permissions.sh install < bucketpolicy.json
#   OR
#   bin/manage-codedeploy-permissions.sh install  bucketpolicy.json
#   OR
#   cat bucketpolicy.json | bin/manage-codedeploy-permissions.sh install
#
# This is a little tricky to test because you have to have the environment set up for dev for the last step.
# But this one command should do it if you have your dev and prod envs set up as suggested on Confluence:
# https://confluence.hobsons.com/pages/viewpage.action?pageId=31658103#AWSMoveTips&Tricks-Configuringcloud-deployment-scriptsforhobsons-navianceprod
#
#     cp env-hobsons-naviancedev.sh env.sh && bin/manage-codedeploy-permissions.sh generate | bin/manage-codedeploy-permissions.sh install

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enable to see every shell command
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
source "$DIR/common.sh"

ensure_awscli
ensure_jq

action=${1:-generate}
BUCKET_NAME="${2:-unmanaged-codedeploy-253369875794}"
INPUT="${3:-/dev/stdin}"

# Returns the JSON bucket policy
function manage-codedeploy-permissions::get-json() {
    cat <<END_OF_JSON
    {
        "Version": "2012-10-17",
        "Statement": [
        {
            "Sid": "989043056009-root-list",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::989043056009:root"
            },
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}"
        },
        {
            "Sid": "989043056009-root-get",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::989043056009:root"
            },
            "Action": [
                "s3:Get*"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
END_OF_JSON
}

if [[ "${action}" = "generate" ]]; then

    json="$(manage-codedeploy-permissions::get-json)"
    json="$(echo "${json}" | jq -c .)"
    echo "${json}"

elif [[ "${action}" = "install" ]]; then

    json=""
    while read -r line
    do
      json="${json}${line}"
    done < "${INPUT}"

    aws \
        s3api \
        put-bucket-policy \
        --bucket "${BUCKET_NAME}" \
        --policy "${json}"

else
    echo "Invalid command.  Valid commands are: generate, install."
fi
