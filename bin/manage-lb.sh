#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enable to see every shell command
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
LB_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$LB_DIR/common.sh"

ensure_awscli

AWS_ACCOUNT=$(get_aws_account_alias)
AWS_ACCOUNT_ID=$(get_aws_account_id)

echo "Running on ${AWS_ACCOUNT}(${AWS_ACCOUNT_ID})"
