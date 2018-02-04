#!/usr/bin/env bash

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
. "$DIR/../../env.sh"

# If you use another region, set these environment variables
# These are set up with AMIs from us-east-1.
# See these URLs in the "Manual Launch" tab for alternate AMI IDs for other regions:
#  CentOS 6: https://aws.amazon.com/marketplace/fulfillment?productId=74e73035-3435-48d6-88e0-89cc02ad83ee&ref_=dtl_psb_continue&region=us-east-1
#  CentOS 7: https://aws.amazon.com/marketplace/fulfillment?productId=b7ee8a69-ee97-4a49-9e68-afaee216db2e&launch=oneClickLaunch
#  Ubuntu 16.04: https://aws.amazon.com/marketplace/fulfillment?productId=d83d0782-cb94-46d7-8993-f4ce15d1a484&ref_=dtl_psb_continue&region=us-east-1
export AWS_AMI_UBUNTU_16_04=${AWS_AMI_UBUNTU_16_04:-ami-f0768de6}
export AWS_COPY_REGIONS=${AWS_COPY_REGIONS:-false}

# These are the default Hobsons Naviance Dev VPC ids in us-east-1
export PACKER_AWS_VPC_ID=${PACKER_AWS_VPC_ID:-vpc-22cbf844}
export PACKER_AWS_SUBNET_ID=${PACKER_AWS_SUBNET_ID:-subnet-e72437ca}

export SPLUNK_INDEXER=${SPLUNK_INDEXER:-172.31.65.7}

export PACKER_JSON=${PACKER_JSON:-machines/all.json}
get_config="$DIR/../../bin/get_config.py"
# Sort out the AWS account situation
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
    creds="$HOME/.aws/credentials"
    if [[ -f "$creds" ]]; then
        export AWS_DEFAULT_PROFILE=${AWS_DEFAULT_PROFILE:-default}
        AWS_ACCESS_KEY_ID=$("$get_config" "$HOME/.aws/credentials" "$AWS_DEFAULT_PROFILE" aws_access_key_id)
        AWS_SECRET_ACCESS_KEY=$("$get_config" "$HOME/.aws/credentials" "$AWS_DEFAULT_PROFILE" aws_secret_access_key)
        export AWS_ACCESS_KEY_ID
        export AWS_SECRET_ACCESS_KEY
        AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-$("$get_config" "$HOME/.aws/credentials" "$AWS_DEFAULT_PROFILE" region)}
    fi
fi
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
export AWS_REGION=${AWS_DEFAULT_REGION}

cd "$DIR/.."
arg=$(sed 's/^-*//' <<<"${1:-}")
case $arg in
    prep)
        if [[ "$AWS_COPY_REGIONS" != true ]]; then
            jq -f "$DIR/del-ami_regions.jq" "$PACKER_JSON" > "$PACKER_JSON".tmp
        else
            cp "$PACKER_JSON" "$PACKER_JSON".tmp
        fi
        ;;
    prereq)
        cat <<EOF
Environment variables (override these for non-default profile & region)
AWS_PROFILE=$AWS_PROFILE
PACKER_AWS_VPC_ID=$PACKER_AWS_VPC_ID
PACKER_AWS_SUBNET_ID=$PACKER_AWS_SUBNET_ID
AWS_AMI_UBUNTU_16_04=$AWS_AMI_UBUNTU_16_04
EOF
        "$DIR/../../bin/install-jq.sh"
	    "$DIR/check-prerequisites.sh"
        ;;

    validate)
        # Thanks pporada for the docker run string https://hub.docker.com/r/hashicorp/packer/
        # Thanks Stask Overflow for the environment variable passing: https://stackoverflow.com/a/30494145/424301
        docker run -i \
            -v "$(pwd)":/opt/packer-src \
            -e PACKER_AWS_VPC_ID="$PACKER_AWS_VPC_ID" \
            -e PACKER_AWS_SUBNET_ID="$PACKER_AWS_SUBNET_ID" \
            -e AWS_AMI_UBUNTU_16_04="$AWS_AMI_UBUNTU_16_04" \
            -e SPLUNK_INDEXER="${SPLUNK_INDEXER:-}" \
            -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-}" \
            -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}" \
            -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}" \
            hashicorp/packer:light \
            validate /opt/packer-src/"$PACKER_JSON"
        ;;
    build)
		docker run -i \
            -v "$(pwd)":/opt/packer-src \
            -e PACKER_AWS_VPC_ID="$PACKER_AWS_VPC_ID" \
            -e PACKER_AWS_SUBNET_ID="$PACKER_AWS_SUBNET_ID" \
            -e AWS_AMI_UBUNTU_16_04="$AWS_AMI_UBUNTU_16_04" \
            -e SPLUNK_INDEXER="${SPLUNK_INDEXER:-}" \
            -e AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-}" \
            -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}" \
            -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}" \
            hashicorp/packer:light \
            build /opt/packer-src/"$PACKER_JSON".tmp
        ;;
    post)
        # Only post-process if we have built all the machines
        if [[ "$PACKER_JSON" =~ machines/all.json$ ]]; then
		    "$DIR/post-process-amis.sh"
        else
            echo "Skipping post-processing since we are not building all machines"
        fi
        ;;
    *)
        echo "ERROR: must specify either prereq, vaidate, or build"
        ;;
esac

