#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enable to see every shell command
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
WAF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$WAF_DIR/common.sh"

ensure_awscli

AWS_ACCOUNT=$(get_aws_account_alias)
AWS_ACCOUNT_ID=$(get_aws_account_id)

WAF_LOG_S3_BUCKET_PREFIX=unmanaged-alb-logs
WAF_LOG_S3_BUCKET="${WAF_LOG_S3_BUCKET_PREFIX}-${AWS_ACCOUNT_ID}"

WAF_GLOBAL_STACK_NAME="tf-waf-stack-count"

declare -a ALB_ARNS

function manage-waf::check() {
  WEB_ACL_NAME=${1:-$WAF_GLOBAL_STACK_NAME}
  ACL_ID=$(aws waf-regional list-web-acls | jq -r '.WebACLs[] | select(.Name | contains("'"${WEB_ACL_NAME}"'")) | .WebACLId' | sed 's/\\[t]/\ /g')
  if [[ ! -n "${ACL_ID}" ]]; then
    echo "FATAL: WebACL for WAF rules does not exist, please run ./bin/manage-cf-waf-stack.sh create"
    exit 1
  fi
}

function manage-waf::get-alb-arns() {
  ALL_ALB_ARNS=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[].LoadBalancerArn' \
    --output text)

  for ARN in $ALL_ALB_ARNS; do
    VALID_ARN=$(aws elbv2 describe-tags --resource-arns "${ARN}" | jq -r '.TagDescriptions[] | select(.Tags[] | .Key | contains("associate_with_waf")) | .ResourceArn')
    if [[ ! -z "$VALID_ARN" ]]; then
      ALB_ARNS+=("$VALID_ARN")
    fi
  done
}

function manage-waf::create() {
  WAF_STACK_TEMPLATE_PATH="${WAF_DIR}/../cloudformation/waf/aws-waf-security-automations-alb.json"

  if [ -e "${WAF_STACK_TEMPLATE_PATH}" ]; then
    echo "Running in ${AWS_ACCOUNT_ID} (${AWS_ACCOUNT})"
    # Idempotent Bucket operation
    aws s3 mb "s3://${WAF_LOG_S3_BUCKET}"
    set +e
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "${WAF_GLOBAL_STACK_NAME}" 2>/dev/null | jq -r .Stacks[0].StackStatus)
    if [[ "${STACK_STATUS}" != "CREATE_COMPLETE" ]] || [[ "${STACK_STATUS}" != "UPDATE_COMPLETE" ]]; then
      # Stack Does Not Exist, lets create it.
      aws cloudformation create-stack \
        --stack-name "${WAF_GLOBAL_STACK_NAME}" \
        --template-body "file://${WAF_STACK_TEMPLATE_PATH}" \
        --no-disable-rollback \
        --parameters ParameterKey=CloudFrontAccessLogBucket,ParameterValue="${WAF_LOG_S3_BUCKET}" ParameterKey=SendAnonymousUsageData,ParameterValue=no \
        --capabilities CAPABILITY_IAM
    fi
  else
    echo "FATAL: Could not find CloudFormation template file: ${WAF_STACK_TEMPLATE_PATH}"
    return 1
  fi
}

function manage-waf::delete() {
  # This fails to delete the IP Set Rules because unexplained AWS brokenness.
  # And since it's a giant pain to manually delete the IP Set, we shall script it.

  #aws waf-regional get-ip-set --ip-set-id 41fc3a72-7827-4b5b-a79f-97008382cc9e --profile hobsons-naviancedev
  aws cloudformation delete-stack --stack-name "${WAF_GLOBAL_STACK_NAME}"
}

function manage-waf::associate() {
  local WAF_STACK_NAME
  WAF_STACK_NAME="${1:-$WAF_GLOBAL_STACK_NAME}"

  manage-waf::check "${WAF_STACK_NAME}"
  manage-waf::get-alb-arns

  for ARN in "${ALB_ARNS[@]}"; do
    echo "Associating $ACL_ID to $ARN"
    aws waf-regional associate-web-acl --web-acl-id "$ACL_ID" --resource-arn "$ARN"
  done
}

function manage-waf::disassociate() {
  local WAF_STACK_NAME
  WAF_STACK_NAME="${1:-$WAF_GLOBAL_STACK_NAME}"

  manage-waf::check "${WAF_STACK_NAME}"
  manage_waf::get-alb-arns

  for ARN in "${ALB_ARNS[@]}"; do
    echo "Disassociating $ARN"
    aws waf-regional disassociate-web-acl --resource-arn "$ARN"
  done
}

function manage-waf::generate-tfvars() {
  manage-waf::check

  # Utilize awesome config script to setup directory and sync config
  "${WAF_DIR}/configs.sh" pull

  # Programatically create tfvars file.
  aws waf-regional list-rules \
    | jq -r '.Rules[] | .Name + " = \"" + .RuleId + "\""' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/\ /-/g' -e 's/\#//g' -e 's/---/-/g' -e 's/-=-/\ =\ /g' \
    > "${WAF_DIR}/../build/configs/${AWS_ACCOUNT}/unmanaged-tf-state-${AWS_ACCOUNT_ID}/shared/waf-rule-ids-${AWS_ACCOUNT_ID}.tfvars"

  # Upload newly generated tfvars
  "${WAF_DIR}/configs.sh" push
}

function manage-waf::main() {
  # We are only passing $2 (acl name) to the associate and disassociate
  # functions, as we will really only create/delete the CloudFormation Stack here
  # Any other ACLs or Rules should be created with Terraform.

  case $1 in
    create)
      manage-waf::create
    ;;
    associate)
      manage-waf::associate "$2"
    ;;
    disassociate)
      manage-waf::disassociate "$2"
    ;;
    generate-tfvars)
      manage-waf::generate-tfvars
    ;;
    delete)
      manage-waf::delete
    ;;
    *)
      cat <<-EOF
Usage: manage-cf-waf-stack.sh <command>

Available commands are:
create            Creates the stack for use.
delete            Deletes the stack.
associate         Associate a WebACL with the ALBs created by terraform.
disassociate      Disassociates ALL WebACLs with the ALBs created by terraform.
generate-tfvars   Generates the needed tfvars file to associate rules with terraform.
EOF
    ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # This should only run if we are not being sourced.
  verb=${1:-"help"}
  acl=${2:-$WAF_GLOBAL_STACK_NAME}
  manage-waf::main "$verb" "$acl"
fi
