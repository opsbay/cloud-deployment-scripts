#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Thanks Stack Overflow https://stackoverflow.com/a/40121084/424301
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
bucket="s3://unmanaged-tf-state-$AWS_ACCOUNT_ID"
latest_amis="latest-amis-$AWS_ACCOUNT_ID.tfvars"
manifest="$DIR/../packer-manifest.json"

tfdir="$DIR/../../terraform"
mkdir -p "$tfdir"

jqscript=$(cat <<"JQSCRIPT"
.last_run_uuid as $last 
    | .builds[] 
    | select(.packer_run_uuid == $last) 
    | .name + " = {", (.artifact_id | split(",") 
    | .[] 
    | "\t" + sub(":"; " = \"") + "\""), "}" 
JQSCRIPT
)

jq -r "$jqscript" "$manifest" > "$tfdir/$latest_amis"

# Upload latest vars to s3
aws s3 mb "$bucket"
aws s3 cp --sse AES256 "$tfdir/$latest_amis"  "$bucket/shared/"
