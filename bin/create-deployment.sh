#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enable to see every shell command
set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$DIR/common.sh"

#shellcheck disable=SC1090
. "$DIR/manage-asg.sh"

ensure_awscli
ensure_unzip

UPSTREAM_BUILD_URL=${1:-}
APP_NAME=${2:-}
APP_SUFFIX=${3:-}
DEPLOYMENT_APP=${4:-}
DEPLOYMENT_GROUP=${5:-}
DEPLOYMENT_CONFIGURATION=${6:-CodeDeployDefault.OneAtATime}
DEPLOYMENT_TARGET=${7:-}
IGNORE_APPLICATION_STOP_FAILURE=${8:-false}
# The AWS Account ID is harcoded here because the CodeDeploy will always use the buckets from the hobsons-navianceprod account
# See https://jira.hobsons.com/browse/NAWS-474 and https://jira.hobsons.com/browse/NAWS-475
AWS_ACCOUNT_ID='253369875794'
UPSTREAM_BUILD_NUMBER=$(parse_build_number "${UPSTREAM_BUILD_URL}")
BUCKET_NAME="unmanaged-codedeploy-${AWS_ACCOUNT_ID}"
S3_FILE="${APP_NAME}/${APP_NAME}${APP_SUFFIX}-${UPSTREAM_BUILD_NUMBER}.zip"
S3_PHP_BUILD_VERSION_FILE="$S3_FILE.php-version.txt"
S3_BUILD_META_FILE="$S3_FILE.meta.txt"
BUILD_DIR="$DIR/../build"
PHP_BUILD_VERSION_FILE="$BUILD_DIR/etc/phpversion.txt"
BUILD_META_FILE="$BUILD_DIR/etc/meta.txt"
AWS_ACCOUNT_ID=$(get_aws_account_id)
BASE_TERRAFORM_STATE_BUCKET="unmanaged-tf-state-${AWS_ACCOUNT_ID}"
BASE_TERRAFORM_APP_BUCKET=$(get_aws_s3_app_config_bucket)

if [[ "$IGNORE_APPLICATION_STOP_FAILURE" = "true" ]]; then
    IGNORE_APPLICATION_STOP_FAILURE_FLAG="--ignore-application-stop-failure"
else
    IGNORE_APPLICATION_STOP_FAILURE_FLAG=""
fi


mkdir -p "$BUILD_DIR/etc" "$BUILD_DIR/$APP_NAME"
set +e
if ! aws s3 cp \
    "s3://$BUCKET_NAME/$S3_PHP_BUILD_VERSION_FILE" \
    "$PHP_BUILD_VERSION_FILE"
then
    # crack PHP version from zip file
    set -e
    # If we can't get the zip file, we should just fail because
    # the codedeploy that follows will fail too.
    aws s3 cp \
        "s3://$BUCKET_NAME/$S3_FILE" \
        "$BUILD_DIR/$S3_FILE"
    cd "$BUILD_DIR"
    set +e
    # But if we are dealing with a non-php build, it's OK to fail on
    # unzipping this phpversion.txt file, it won't exist for a Java project
    # for example
    unzip "$S3_FILE" etc/phpversion.txt
fi

aws s3 cp \
    "s3://$BUCKET_NAME/$S3_BUILD_META_FILE" \
    "$BUILD_META_FILE"
set -e

if [[ -f "$PHP_BUILD_VERSION_FILE" ]]; then
    php_build_version="$(sed -e 's/\.//g' "$PHP_BUILD_VERSION_FILE")"
else
    php_build_version=""
fi

if [[ -f "$BUILD_META_FILE" ]]; then
    build_meta="$(cat "$BUILD_META_FILE")"
fi

if [[ -n "$DEPLOYMENT_TARGET" ]]; then
    application_name="$DEPLOYMENT_APP-$DEPLOYMENT_TARGET"
else
    application_name="$DEPLOYMENT_APP"
fi

if [[ -n "$php_build_version" ]]; then
    application_name="${application_name}-${php_build_version}"
fi

record_to_newrelic() {
    local stage
    local desc
    local index
    local newrelic_app_id
    local app_name
    stage="$1"
    # Replace hyphens with underscores since that's what's in our JSON files
    # that mapp app to NewRelic ID
    app_name="${APP_NAME//-/_}"

    if [[ -n "$php_build_version" ]]; then
        index=".${app_name}_${php_build_version}"
    else
        index=".${app_name}"
    fi

    # Get our NewRelic REST API key
    aws s3 cp --sse AES256 "s3://${BASE_TERRAFORM_STATE_BUCKET}/shared/newrelic-api-key.txt" "$BUILD_DIR/newrelic-api-key.txt"
    . "$BUILD_DIR/newrelic-api-key.txt"

    # Get the NewRelic App ID $APP_NAME
    aws s3 cp --sse AES256 "s3://${BASE_TERRAFORM_APP_BUCKET}/newrelic/application_ids_${DEPLOYMENT_GROUP}.json" "$BUILD_DIR/app_ids.json"

    newrelic_app_id="$(jq -r "${index}" < "$BUILD_DIR"/app_ids.json)"

    case "$stage" in
        begin)
            desc="Beginning"
            ;;
        end)
            #shellcheck disable=SC2034
            desc="Ending"
            ;;
        *)
            echo "ERROR: Unrecognized stage: '$stage'" >2
            exit 1
            ;;
    esac

    # Only send deployment info to NewRelic to apps whose NR keys exist in:
    # s3://${BASE_TERRAFORM_APP_BUCKET}/newrelic/application_ids_${DEPLOYMENT_GROUP}.json
    if [ "null" != "$newrelic_app_id" ]; then
        curl --silent --output /dev/null \
            -X POST "https://api.newrelic.com/v2/applications/${newrelic_app_id}/deployments.json" \
            -H "X-Api-Key:${NEW_RELIC_API_KEY}" -i \
            -H 'Content-Type: application/json' \
            -d \
        "{
          \"deployment\": {
            \"revision\": \"${build_meta}\",
            \"description\": \"${desc} deployment\"
          }
        }"
    fi
}

auto_scaling_group_name="$application_name-$DEPLOYMENT_GROUP-asg"

echo "Suspending autoscaling processes"
manage-asg::suspend-asg-processes "$auto_scaling_group_name"

# Record the beginning of our deployment in NewRelic
record_to_newrelic "begin"

deployment=$(aws deploy create-deployment \
    --application-name "$application_name" \
    --s3-location "bucket=$BUCKET_NAME,key=$S3_FILE,bundleType=zip" \
    --deployment-group-name "$DEPLOYMENT_GROUP" \
    --deployment-config-name "$DEPLOYMENT_CONFIGURATION" \
    --output text \
    "$IGNORE_APPLICATION_STOP_FAILURE_FLAG" \
    --region us-east-1)

# Hand off to monitor script.
set +e
"$DIR/monitor-deployment.sh" "$deployment"
DEPLOYMENT_RESULT=$?
set -e

echo "Resuming autoscaling processes"
#shellcheck disable=SC2064

# If recording to NewRelic fails, make sure we resume ASG processes.
trap "manage-asg::resume-asg-processes \"$auto_scaling_group_name\" && exit \"$DEPLOYMENT_RESULT\"" EXIT

# Record the ending of our deployment in NewRelic
record_to_newrelic "end"

# Reset the trap.
trap - EXIT

manage-asg::resume-asg-processes "$auto_scaling_group_name"

# Fail if the deployment has failed
exit "$DEPLOYMENT_RESULT"
