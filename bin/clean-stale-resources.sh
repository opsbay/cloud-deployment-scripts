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
. "$DIR/../common.sh"

AWS_ACCOUNT_ALIAS=$(get_aws_account_alias)
AWS_ACCOUNT_ID=$(get_aws_account_id)
VERB=${1:-}

echo "Running against ${AWS_ACCOUNT_ALIAS} (${AWS_ACCOUNT_ID})"

# Delete unused EBS volumes.
#
# creating  - The volume is getting created and is not yet ready.
# available - The volume is available for use.
# in-use    - The volume is in use/attached.
# deleting  - The volume is getting deleted.
# error     - The volume is in error state(pray that you have snapshot of it).
# 
# Source: http://www.aodba.com/clean-up-amazon-unused-ebs-volumes-and-lower-costs/
delete_unused_ebs() {
    for unused_volumes in $(aws ec2 describe-volumes \
        --region "${AWS_REGION}" --filters Name=status,Values=available \
        --query 'Volumes[*].VolumeId' --output text); do
        echo "Removing Volume: ${unused_volumes}"
#        aws ec2 delete-volume --region "${AWS_REGION}" --volume-id "${volume_id}"
    done
}

# Deregister unused AMI's.
# 'Unused' is defined as AMI's that are NOT:
#   1. in a whitelist (maintained by hand)
#   2. used by EC2 instances
#   3. in Launch Configuration
deregister_unused_ami() {
    # Manually maintained whitelist of AMI's we want to keep.
    # This could be a list of AMI's taken from the latest-amis-XXX.tfvars file.
    whitelisted_amis=( "ami-38bf9b43" "ami-efb99d94" "ami-0cbe9a77" )

    # Get AMIs by EC2 instances.
    instance_amis=$(aws ec2 describe-instances \
        --query 'Reservations[*].Instances[*].[ImageId]' \
        --output text)

    # Get AMIs in Launch Configurations
    lc_amis=$(aws autoscaling describe-launch-configurations \
        --query 'LaunchConfigurations[*].ImageId' \
        --output text)

    # Combination of AMI's used by EC2 instance volumes and Launch Configurations.
    used_amis=( "${instance_amis[@]}" "${lc_amis[@]}" "${whitelisted_amis[@]}" )

    # Get all AMIs owned by us (i.e. $AWS_ACCOUNT_ID).
    available_amis=$(aws ec2 describe-images \
        --owners "$AWS_ACCOUNT_ID" \
        --query 'Images[*].ImageId' \
        --output text)

    # We delete the used AMI's from the $available_amis var so that we can iterate
    # through the modified array and delete the AMI's in that array.
    for used_ami in "${used_amis[@]}"; do
       available_amis=("${available_amis[@]/$used_ami}")
    done

    # We only delete AMI's if they don't exist because many instances will use the
    # same AMI which may have already been deleted in the previous iteration
    for unused_ami in "${available_amis[@]}"; do
        echo "Deregistering AMI: ${unused_ami}..."
        # aws ec2 deregister-image --image-id $unused_ami --region "${AWS_REGION}"
        # if [ $? == 0 ]; then
        #     echo "Deleted."
        # else
        #     echo "Deletion failed. Terminating."
        #     exit $?
        # fi
    done
}

# Deletes RDS snapshots older than our cutover date (August 23rd, 2017)
delete_unused_rds() {
    snapshot_metas=$(aws rds describe-db-cluster-snapshots \
        --no-paginate \
        --query 'DBClusterSnapshots[*].[SnapshotCreateTime, DBClusterSnapshotIdentifier]' \
        --output text)

    OLD_IFS=$IFS
    IFS=$'\n'
    #shellcheck disable=SC2068
    for snapshot_meta in ${snapshot_metas[@]}; do
        IFS=$'\t'
        read -ra snapshot_meta_parsed <<< "$snapshot_meta"
        human_friendly_date=$(date -d "${snapshot_meta_parsed[0]}")
        # Source: https://stackoverflow.com/a/27429770/379786
        if [ "$(date -d "${snapshot_meta_parsed[0]}" +%s)" -lt "$(date -d "2017-08-23T00:00:00.138Z" +%s)" ]; then
            echo "Deleting snapshot created on ${human_friendly_date} with identifier ${snapshot_meta_parsed[1]}..."
            # aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier "${snapshot_meta_parsed[1]}"
            # if [ $? == 0 ]; then
            #     echo "Deleted."
            # else
            #     echo "Deletion failed. Terminating."
            #     exit $?
            # fi
        else
            echo "Keeping snapshot created on ${human_friendly_date} with identifier ${snapshot_meta_parsed[1]}"
        fi
    done
    IFS=$OLD_IFS
}

delete_unused_snapshot() {
    # For snapshots, delete all that are createad by CreateImage which have the AMI ID's of the AMI's we want to delete.
    :
}

case "$VERB" in
    "ebs")
        delete_unused_ebs
        ;;

    "ami")
        deregister_unused_ami
        ;;

    "snapshot")
        delete_unused_snapshot
        ;;

    "rds")
        delete_unused_rds
        ;;

    "all")
        delete_unused_ebs
        deregister_unused_ami
        delete_unused_snapshot
        delete_unused_rds
        ;;

    *)
        echo "Unrecognized resource '$VERB'"
        ;;
esac

exit 0