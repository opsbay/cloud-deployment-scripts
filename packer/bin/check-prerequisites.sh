#!/bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Thanks Stack Overflow https://stackoverflow.com/a/40121084/424301
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
BASE_TERRAFORM_STATE_BUCKET="unmanaged-tf-state-$AWS_ACCOUNT_ID"
latest_amis="latest-amis-$AWS_ACCOUNT_ID.tfvars"
latest_amis_s3_obj="s3://${BASE_TERRAFORM_STATE_BUCKET}/shared/${latest_amis}"

prereq='
jq
docker
'
for req in $prereq; do
    if [[ -z "$(which "$req")" ]]; then
        echo "ERROR: $req not found, please install $req before proceeding"
        exit 1
    fi
done

set +e
if ! aws s3 ls "$latest_amis_s3_obj" >/dev/null 2>&1; then
    aws s3 mb "s3://${BASE_TERRAFORM_STATE_BUCKET}"
fi
set -e
