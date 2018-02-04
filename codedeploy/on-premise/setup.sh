#!/usr/bin/env bash

# Steps for this script was taken from:
# http://docs.aws.amazon.com/codedeploy/latest/userguide/register-on-premises-instance-iam-user-arn.html

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# TODO: I had to hardcode this because Vagrant seems to be seeing ${BASH_SOURCE[0]} as /tmp/...
## That's a normal workaround for Vagrant -Richard
BASEDIR="/vagrant/codedeploy/on-premise"
USER_ENV="/vagrant/env.sh"

#shellcheck disable=SC1090
{
if [[ -f "$USER_ENV" ]]; then
    . "$USER_ENV"
fi

. "$BASEDIR/common.sh"


export AWS_DEFAULT_PROFILE="${2:-default}"

case "${1:-}" in
    "up")
        . "$BASEDIR/tasks/create-user.sh"
        . "$BASEDIR/tasks/configure-codedeploy.sh"
        . "$BASEDIR/tasks/register-instance.sh"
        . "$BASEDIR/tasks/configure-deployment.sh"

        # Run some checks to make sure everything is as it should be.
        . "$BASEDIR/tasks/check.sh"

        Out.green "Make sure you run a deployment as the 'root' user in Vagrant."
    ;;

    "down")
        . "$BASEDIR/tasks/destroy-user.sh"
    ;;

    "check")
        . "$BASEDIR/tasks/check.sh"
    ;;

    *)
        echo "$0: Unknown command: '$1'"
        exit 1
    ;;
esac


Out.green "All done!"
}
exit 0
