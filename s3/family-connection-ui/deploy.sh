#!/usr/bin/env bash
#
# deploy.sh
#
# Syntax:
#
#    deploy.sh [S3-bucket-name]
#
# If S3-bucket-name is omitted, this deploys to the QA environment bucket.
#
# Examples:
#
# Deploy to QA
#
#     s3/family-connection-ui/deploy.sh
#
# Deploy to Staging
#     s3/family-connection-ui/deploy.sh family-connection-ui-staging.devops.naviance.com https://tf-blue-ridge-api-staging.devops.naviance.com

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
. "$DIR/../../bin/common.sh"

ensure_awscli

# Thanks Stack Overflow https://stackoverflow.com/a/40121084/424301
AWS_ACCOUNT_ID=$(get_aws_account_id)

LONG_CACHE_TTL=$(( 365 * 60 * 60 * 24)) # one year
SHORT_CACHE_TTL=$(( 5 * 60 ))           # five minutes

if [[ -n "${BUILD_NUMBER:-}" ]]; then
    id="jenkins-$BUILD_NUMBER"
else
    timestamp=$(perl -MPOSIX -le 'print strftime("%s", localtime())')
    id="$timestamp"
fi

# Command line parameters to override targets
target=${1:-family-connection-ui-qa.devops.naviance.com}
api_host=${2:-https://tf-blue-ridge-api-qa.devops.naviance.com}
skip_run=${3:-false}
cache=${4:-true}
use_ci_build=${5:-false}
certificate=${6:-arn:aws:acm:us-east-1:253369875794:certificate/717bb4c1-b53b-4f22-9710-a8d9bf3f361b}
fetch_max_results=${7:-100}
google_map_api_key=${8:-AIzaSyBg5gkvUVAG9oLXboavgTaw9jO-T5yeCDY}
gtm_code=${9:-GTM-NPKP2M}
hubs_app_url=${10:-https://qa-fc-hubs-app.naviance.com}



# Derived variables
bucket="s3://$target"
SRC="$DIR/../../../family-connection-ui"

cd "$SRC"

# Create the build files in family-connection-ui
DOCKERFILE_NAME=Dockerfile

CONTAINER_TAG_NAME="fc-ui:latest-${id}"
APP_PATH=app
if [[ "$skip_run" != "true" ]]; then
    # Use Docker to build family-connection-ui
    if [[ ! -f .npmrc ]]; then
        cp ~/.npmrc .npmrc
    fi
    if [[ "$cache" != "true" ]]; then
        cache_flag=--no-cache
    else
        cache_flag=
    fi
    docker build $cache_flag -f "$DOCKERFILE_NAME" . -t "$CONTAINER_TAG_NAME"
    echo "Docker built OK with $DOCKERFILE_NAME"
    npm_target="build"
    if [[ "$use_ci_build" == "true" ]]; then
        echo "Adapting build for test friendliness"
        echo "see: https://github.com/naviance/family-connection-ui/pull/283"
        echo "     https://jira.hobsons.com/browse/NAWS-497"
        npm_target="${npm_target}:ci"
    fi
    docker run --rm -i -v "$(pwd)":/"$APP_PATH" "$CONTAINER_TAG_NAME" /bin/bash <<EOF
set -euo pipefail
set -x
cd "$APP_PATH"
export API_HOST="$api_host"
export FETCH_MAX_RESULTS="$fetch_max_results"
export GOOGLE_MAP_API_KEY="$google_map_api_key"
export GTM_CODE="$gtm_code"
export HUBS_APP_URL="$hubs_app_url"
npm i
npm run "$npm_target"
EOF
fi
echo "Build files created."

#creating a aws s3 bucket for family-connetion-ui
echo "Deploying latest build to $bucket in account $AWS_ACCOUNT_ID"
if ! aws s3 ls "$bucket" > /dev/null; then
    aws s3 mb "$bucket"
fi
cd "$SRC/build"
aws s3 website "$bucket" \
    --index-document index.html \
    --error-document index.html
aws s3 sync . "$bucket" \
    --acl public-read \
    --exclude "index.html" \
    --exclude "sw.js" \
    --cache-control max-age="$LONG_CACHE_TTL"
for file in index.html sw.js; do
    aws s3 cp "$file" "$bucket/$file" \
        --acl public-read \
        --cache-control max-age="$SHORT_CACHE_TTL"
done

mkdir -p "${DIR}/build/"

# aws cloudfront creation for staging environment
aws configure set preview.cloudfront true
domain_name=$(cut -d. -f 2- <<<"$target")
function get_distribution_id () {
    local target=${1:-}
    aws cloudfront list-distributions \
      --query "DistributionList.Items[?Aliases.Items!=null] | [?contains(Aliases.Items, '$target')].Id | [0]" \
      --output text
}
distribution_id="$(get_distribution_id "$target")"

cfdist="$DIR/build/cloudfront-distribution-config.json"
callerReference="fc-ui-deploy-$id"
cat > "$cfdist" <<EOF
{
    "CallerReference": "$callerReference",
    "DefaultRootObject": "index.html",
    "Origins": {
    "Items": [
        {
          "S3OriginConfig": {
          "OriginAccessIdentity": ""
        },
        "OriginPath": "",
        "CustomHeaders": {
            "Quantity": 0
            },
            "Id": "S3-$target",
            "DomainName": "$target.s3.amazonaws.com"
        }
    ],
    "Quantity": 1
    },
    "DefaultCacheBehavior": {
      "TargetOriginId": "S3-$target",
      "ForwardedValues": {
        "QueryString": false,
        "Cookies": {
          "Forward": "none"
        }
      },
      "TrustedSigners": {
        "Enabled": false,
        "Quantity": 0
      },
      "ViewerProtocolPolicy": "redirect-to-https",
      "MinTTL": 3600
    },
    "CacheBehaviors": {
        "Quantity": 0
    },
    "CustomErrorResponses": {
       "Quantity": 2,
       "Items": [
         {
           "ErrorCode": 403,
           "ResponsePagePath": "/index.html",
           "ResponseCode": "200",
           "ErrorCachingMinTTL": 300
         },
         {
           "ErrorCode": 404,
           "ResponsePagePath": "/index.html",
           "ResponseCode": "200",
           "ErrorCachingMinTTL": 300
         }
       ]
     },
    "Comment": "",
    "Logging": {
        "Enabled": false,
        "IncludeCookies": true,
        "Bucket": "",
        "Prefix": ""
    },
    "ViewerCertificate": {
        "SSLSupportMethod": "sni-only",
        "ACMCertificateArn": "$certificate",
        "MinimumProtocolVersion": "TLSv1",
        "Certificate": "$certificate",
        "CertificateSource": "acm"
    },
    "Aliases": {
        "Items": [
            "$target"
        ],
        "Quantity": 1
    },
    "PriceClass": "PriceClass_All",
    "Enabled": true
}
EOF
echo "Cloudfront distribution_id: $distribution_id"
if [[ -z "$distribution_id" ]] || [[ "$distribution_id" = "None" ]]; then
    echo "Creating cloudfront distribution"
    aws cloudfront create-distribution --distribution-config "file://$cfdist"
fi
distribution_id=$(aws cloudfront list-distributions \
     --query "DistributionList.Items[?Aliases.Items!=null] | [?contains(Aliases.Items, '$target')].Id | [0]" \
     --output text)
echo "Cloudfront distribution_id: $distribution_id"
cloudfront_domain=$(aws cloudfront get-distribution \
    --id "$distribution_id" \
    --query 'Distribution.DomainName' \
    --output text)
echo "cloudfront domain: $cloudfront_domain"
cat > "$DIR/build/route53-change-batch.json" <<EOF
{
    "Comment": "Upsert route53 resource record set for $target",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$target",
                "Type": "CNAME",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$cloudfront_domain"
                    }
                ]
            }
    }
  ]
}
EOF

hosted_zone=$(aws route53 list-hosted-zones --query 'HostedZones[? Name == `'"$domain_name"'.`].Id' --output text | cut -d/ -f 3 )
echo "Hosted zone: $hosted_zone"

# aws record set change
aws route53 change-resource-record-sets --hosted-zone-id "$hosted_zone" --change-batch "file://$DIR/build/route53-change-batch.json"
# aws cloudfront invalidation for s3 bucket
# http://aws-blog.io/2015/create-cloudfront-distribution/
distribution_id=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?Aliases.Items!=null] | [?contains(Aliases.Items, '$target')].Id | [0]" \
    --output text)
echo "$distribution_id"
# Before we were invalidating "/*" but since we only have 2 files that get overwritten we only
# need to invalidate those.
# See: https://jira.hobsons.com/browse/NTU-1498
invalidation_batch='{"Paths": {"Quantity": 2,"Items": ["/index.html","/sw.js"]},"CallerReference": "'$callerReference'"}'
aws cloudfront create-invalidation \
    --distribution-id "${distribution_id}" \
    --invalidation-batch "$invalidation_batch"
