#!/usr/bin/env bash
#
# configs.sh
#
# This script will allow a user to `pull` or `push` application configs from S3 buckets for editing.
#
# Syntax:
#
#    bin/configs.sh <push>|<pull>|<clean>|<help>

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enable for enhanced debugging
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$DIR/common.sh"


function help_text() {
cat <<EOF

SYNOPSIS
    $0 <ACTION>

    Manages configuration files located at:
        s3://unmanaged-app-config-${AWS_ACCOUNT_ID}/
        s3://unmanaged-tf-config-${AWS_ACCOUNT_ID}/shared/

    The app-config   is for application-level configuration information.
    The tf-config   is for account-level configuration information.

DESCRIPTION
    ACTION
        push
            Pushes configs into S3 buckets
            Will only proceed if the timestamps in the S3 bucket are older
            than the ones on the local filesystem.

        pull
            Pulls configs from S3 buckets

        clean 
            Removes files in $DIR/../build/configs

        help 
            Prints help text
EOF
}

declare_target

action="${1:-help}"
AWS_ACCOUNT_ID=$(get_aws_account_id)
app_config_target="$DIR/../build/configs/$(get_aws_account_alias)/unmanaged-app-config-${AWS_ACCOUNT_ID}"
tf_state_target="$DIR/../build/configs/$(get_aws_account_alias)/unmanaged-tf-state-${AWS_ACCOUNT_ID}"

app_config_bucket="s3://unmanaged-app-config-${AWS_ACCOUNT_ID}/"
tf_state_bucket="s3://unmanaged-tf-state-${AWS_ACCOUNT_ID}/"

# This will halt a sync from target to S3 if the file on S3 is newer than the file on target.
function race_check() {
    local bucket="${1}"
    local target="${2}"
    local dryrun
    local dryrun_pattern
    local bucket_date
    local target_date
    local bucket_file
    local target_file

    # Dry run to get the files to be uploaded.
    dryrun=$(aws s3 sync "${target}" "${bucket}" \
        --sse AES256 \
        --dryrun)

    # Pattern to capture file names from dry run.
    dryrun_pattern="\(dryrun\) upload:\ ([^\ ]+) to ([^$]+)$"

    # Patterns to capture dates from files on S3 and target.
    bucket_pattern="^([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})"

    while read -r line; do
        # Capture file names from the dry run output.
        if [[ "$line" =~ $dryrun_pattern ]]; then
            target_file="${BASH_REMATCH[1]}"
            bucket_file="${BASH_REMATCH[2]}"
            bucket_date=1

            set +e
            bucket_out=$(aws s3 ls "${BASH_REMATCH[2]}")
            set -e

            # Capture the date and turn them into seconds since epoch.
            # Thanks to StackOverflow for the nifty perl line.
            # https://unix.stackexchange.com/questions/255524/full-file-date-without-gnu-utilities/255529#255529
            target_date=$(perl -MPOSIX -le 'print strftime("%s", localtime((lstat(shift))[9]))' "${BASH_REMATCH[1]}")
            if [[ "$bucket_out" =~ $bucket_pattern ]]; then
                # Thanks Stack Overflow https://stackoverflow.com/a/20305657/424301
                bucket_date=$(perl -MHTTP::Date -wle "print str2time(\"${BASH_REMATCH[1]}\")")
            fi

            # Compare the seconds to determine how old the files are.
            if [[ "$bucket_date" -ge "$target_date" ]]; then
                echo "ERROR: Push sync denied because the file '$bucket_file' is newer than '$target_file'."
                echo "Please perform a 'pull' first."
                exit 1
            fi  
        fi
    done <<< "$dryrun"
}

function get_diff() {
    local dryrun_pattern
    local dryrun_app
    local tempfile
    local bucket
    local target
    local name

    bucket=${1:-}
    target=${2:-}
    name=${3:-}
    # Pattern to grab bucket file and download location of file.
    dryrun_pattern="\(dryrun\) (down|up)load:\ ([^\ ]+) to ([^$]+)$"
    dryrun_app=$(aws s3 sync "${bucket}" "${target}" \
        --exact-timestamps \
        --sse AES256 \
        --delete --dryrun)
    tempfile=$(mktemp)

    echo ""
    echo "Diff output: $name"
    while read -r line; do
        # Capture file names from the dry run output.
        if [[ "$line" =~ $dryrun_pattern ]]; then
            bucket_file="${BASH_REMATCH[2]}"
            target_file="${BASH_REMATCH[3]}"

            if [[ -f "$target_file" ]]; then
                aws s3 cp "${bucket_file}" "${tempfile}" \
                    --sse AES256 \
                    --quiet
                echo "Showing diff for ${target_file}"
                # Diff the file on disk with a temporarily downloaded file.
                set +e
                diff -u "${target_file}" "${tempfile}" 
                echo ""
                set -e
                rm "${tempfile}"
            fi
        fi
    done <<< "$dryrun_app"
    echo "End of diff output."
    echo ""
}

case "${action}" in
    push)
        race_check "${app_config_bucket}" "${app_config_target}"
        race_check "${tf_state_bucket}" "${tf_state_target}"
        aws s3 sync "${app_config_target}" "${app_config_bucket}" \
            --sse AES256
        aws s3 sync "${tf_state_target}" "${tf_state_bucket}" \
            --sse AES256 \
            --exclude "*" \
            --include "shared/*"
    ;;
    pull)
        # Get a diff before we pull down our changes so we are aware of what is changed.
        get_diff "$app_config_bucket" "$app_config_target" "unmanaged-app-config"
        get_diff "$tf_state_bucket" "$tf_state_target" "unmanaged-tf-state"

        # We do a delete here to help keep stale config files we want to delete from the
        # target buckets from popping back into those buckets if people do a push / pull with
        # an older copy.
        #
        # This is safer than deleting on push as that has the potential to really mess things
        # up if you accidentally delete a file or directory when you are editing config files.
        aws s3 sync "${app_config_bucket}" "${app_config_target}" \
            --exact-timestamps \
            --sse AES256 \
            --delete
        aws s3 sync "${tf_state_bucket}" "${tf_state_target}" \
            --sse AES256 \
            --exact-timestamps \
            --delete \
            --exclude "*" \
            --include "shared/*"

        # TODO: If '--diff' is passed through, show a diff of files pulled.
    ;;
    clean)
        rm -rf "$DIR/../build/configs"
    ;;
    help)
        help_text
        exit 0
    ;;
    *)
        echo "ERROR: Invalid 'ACTION' provided: $action"
        help_text
        exit 1
    ;;
esac

exit 0
