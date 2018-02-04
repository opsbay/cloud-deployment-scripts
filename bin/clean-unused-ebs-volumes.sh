#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
# set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$DIR/common.sh"

AWS_ACCOUNT_ALIAS=$(get_aws_account_alias)
AWS_ACCOUNT_ID=$(get_aws_account_id)

echo "Running against ${AWS_ACCOUNT_ALIAS} (${AWS_ACCOUNT_ID})"

for volume_id in $(aws ec2 describe-volumes \
    --region "${AWS_REGION}" --filters Name=status,Values=available \
    --query 'Volumes[*].VolumeId' --output text); do
    echo "Removing Volume: ${volume_id}"
    aws ec2 delete-volume --region "${AWS_REGION}" --volume-id "${volume_id}"
done