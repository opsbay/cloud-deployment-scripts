#!/usr/bin/env bash
#
#
#
# Attempts to send an email through the specified mail server
# Returns a non-zero exit code on failure.

set -uo pipefail

default_from_email=something@example.com
default_to_email=sean.mccleary@moduscreate.com
default_mail_server=sjc2iu-mailcatcher01.local.naviance.com

# NOTE: This requires Heirloom mailx and won't work with e.g. BSD mailx
# (So most Linuxes are fine; OSX is not fine.)
# Heirloom mailx supports the -V flag while BSD's doesn't. Let's use that
# to look.
mailx -V &> /dev/null
mailx_exit_code=$?
if ((mailx_exit_code != 0))
then
    echo "This requires Heirloom mailx and won't work with e.g. BSD mailx"
    exit 1
fi

from_email=${1:-$default_from_email}
to_email=${2:-$default_to_email}
mail_server=${3:-$default_mail_server}


iso8601_date=$(date -u "+%Y%m%dT%H%M%SZ")
subject="Email connectivity test $iso8601_date"
body="Test message to ensure connectivity"

echo "$subject"
echo "Sending mail from $from_email to $to_email through $mail_server"

echo "$body" | timeout 10 mailx -S DEAD=/dev/null -S smtp="$mail_server" -s "$subject" -r "$from_email" -v "$to_email"
mailx_exit_code=$?
if [[ $mailx_exit_code != 0 ]]
then
    echo "Failure."
    exit $mailx_exit_code
fi
echo "Success."
