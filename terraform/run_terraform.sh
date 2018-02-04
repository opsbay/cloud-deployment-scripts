#!/usr/bin/env bash

# Set bash unofficial strict mode http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enable for enhanced shell debugging
#set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$DIR/../bin/common.sh"

#shellcheck disable=SC1090
. "$DIR/../bin/manage-cf-waf-stack.sh"

#shellcheck disable=SC1090
. "$DIR/../bin/manage-asg.sh"

########### function definitions for run_terraform.sh

function aws-s3-copy-if-exists() {
    src=${1:-}
    dst=${2:-.}
    set +e
    if aws s3 ls "$src" > /dev/null 2>&1; then
        aws-s3-cp --sse AES256 "$src" "$dst"
    fi
    set -e
}

function aws-s3-cp() {
    set +e
    try_with_backoff aws s3 cp "$@"
    result="$?"
    set -e
    return "$result"
}

# Save EFS mount targets to a temp file and moves it to S3
function upload-efs-target() {
    local config="efs-mount-targets"
    local efs_targets_obj="s3://${APP_CONFIG_BUCKET}/efs/${config}.json"
    local tempdir
    tempdir=$(mktemp -d)

    terraform output -json -module=efs > "${tempdir}/${config}.json"
    aws-s3-cp --sse AES256 "${tempdir}/${config}.json" "${efs_targets_obj}"

    # Clean up tempdir
    rm -rf "${tempdir}"
}

# Saves terraform JSON output to a temp file and moves it to S3.
function upload-elasticache-creds() {
    local tempdir
    local search
    local replace
    local cache_info
    local OIFS
    local -a cluster_ids
    local cluster_info

    tempdir=$(mktemp -d)

    # TODO: Check if CacheClusters.CacheClusterStatus is 'available'
    # TODO: Check if CacheClusters.CacheNodes[].CacheNodeStatus is 'available'
    # TODO: Check if CacheClusters.CacheNodes[].ParameterGroupStatus is 'in-sync'
    search="-"
    replace="_"
    cache_info=$(mktemp -d)

    OIFS=$IFS
    IFS=$' '
    cluster_ids=( \
        'tf-testapp-p-cache-s' \
        'tf-testapp-p-cache-d' \
        'tf-perftest-cache-s' \
        'tf-perftest-cache-d'
    )
    cluster_info=""
    for cluster_id in "${cluster_ids[@]}"; do
        aws elasticache describe-cache-clusters \
            --show-cache-node-info \
            --cache-cluster-id "$cluster_id" \
            > "$cache_info/$cluster_id"
        # Jinja2 doesn't seem to like hyphens in variable names so we replace it with underscores.
        cluster_id_parsed=${cluster_id//"$search"/"$replace"}
        # Credit to Stack Exchange: https://unix.stackexchange.com/a/209070/139914
        cluster_info="$(
            jq -r '.CacheClusters[] 
            | select(.CacheClusterId == "'"$cluster_id"'") 
            | {"'"$cluster_id_parsed"'": [.CacheNodes[].Endpoint]}' "$cache_info/$cluster_id")"
        # See https://jira.hobsons.com/browse/NAWS-1069 - lets not make everyone rewrite existing
        # config files, so we fake being the other servers when we are emitting perftest info.
        sed 's/tf_perftest/tf_testapp_p/' \
            <<<"$cluster_info"  \
            > "${tempdir}/${cluster_id}.json"

        aws-s3-cp \
            --sse AES256 \
            "${tempdir}/${cluster_id}.json" \
            "s3://${APP_CONFIG_BUCKET}/elasticache/${cluster_id}.json"
    done
    IFS=$OIFS

    # Cleaning up.
    rm -rf "${tempdir}"
}

# Saves database configuration to a temp file and moves it to S3 in:
# * gradle properties file format
# * json format
# * yaml format
function upload-aurora-cluster-creds() {
    local cluster_module
    local prefix
    local creds
    local endpoint
    local aurora_creds_s3_obj
    local aurora_endpoint_s3_obj
    local tempdir
    
    tempdir=$(mktemp -d)
    for cluster_module in "aurora-cluster-v2" "aurora-cluster-perftest-v1"; do
        prefix=$(sed 's/-v.*$//' <<<"$cluster_module")
        creds="$prefix-creds"
        endpoint="$prefix-endpoint"
        aurora_creds_s3_obj="s3://${BASE_TERRAFORM_STATE_BUCKET}/output/aurora-cluster/${creds}"
        aurora_endpoint_s3_obj="s3://${APP_CONFIG_BUCKET}/aurora-cluster/${endpoint}"

        terraform output -module="$cluster_module" > "${tempdir}/${creds}.properties"
        # Blacklist the things we do not want
        grep -Ev '^(master|default)' \
            "${tempdir}/${creds}.properties" \
            > "${tempdir}/${endpoint}.properties"
        aws-s3-cp --sse AES256 "${tempdir}/${creds}.properties" "${aurora_creds_s3_obj}.properties"
        aws-s3-cp --sse AES256 "${tempdir}/${endpoint}.properties" "${aurora_endpoint_s3_obj}.properties"

        terraform output -json -module="$cluster_module" > "${tempdir}/${creds}.json"
        # Blacklist the things we do not want
        jq 'delpaths([
            ["master_password"],
            ["master_username"],
            ["default_database_name"]])' \
            < "${tempdir}/${creds}.json" \
            > "${tempdir}/${endpoint}.json"
        aws-s3-cp --sse AES256 "${tempdir}/${creds}.json" "${aurora_creds_s3_obj}.json"
        aws-s3-cp --sse AES256 "${tempdir}/${endpoint}.json" "${aurora_endpoint_s3_obj}.json"

        # Convert json to yaml
        ruby -ryaml -rjson -e 'puts YAML.dump(JSON.parse(STDIN.read))' < "${tempdir}/${creds}.json" > "${tempdir}/${creds}.yaml"
        # Blacklist the things we don't want
        # Thanks Unix Stack Exchange https://unix.stackexchange.com/a/56166/137901
        # Depends on GNU sed - won't work on Mac OS X
        sed '/\(default_database_name\|master_username\|master_password\)/,+3 d' \
            < "${tempdir}/${creds}.yaml" \
            > "${tempdir}/${endpoint}.yaml"
        aws-s3-cp --sse AES256 "${tempdir}/${creds}.yaml" "${aurora_creds_s3_obj}.yaml"
        aws-s3-cp --sse AES256 "${tempdir}/${endpoint}.yaml" "${aurora_endpoint_s3_obj}.yaml"

    done
    # Cleaning up.
    rm -rf "${tempdir}"
}

function ensure-branch-protect() {
  set +e
  if which git > /dev/null 2>&1; then
    echo "git"
  fi
}

function set-role-variables() {
  # Determine if we are using a role, and set credentials appropriately.
  caller_ident=$(aws sts get-caller-identity --query "Arn" --output text)
  if [[ ${caller_ident} =~ ^arn:aws:sts::[0-9]+:assumed-role ]]; then
    # Get name of the role

    arn=$("${DIR}/../bin/get_config.py" "${HOME}/.aws/config" "profile ${AWS_PROFILE}" role_arn) || arn=$("${DIR}/../bin/get_config.py" "${HOME}/.aws/credentials" "${AWS_PROFILE}" role_arn)

    # Get Temp Credentials
    assume_output=$(aws sts assume-role \
      --role-arn "${arn}" \
      --role-session-name "local-terraform-${USER}" \
      --query 'Credentials.[SecretAccessKey,SessionToken,AccessKeyId]' \
      --output text)

    declare -a credentials
    IFS=$'\t' read -r -a credentials <<< "${assume_output}"
    export AWS_SECRET_ACCESS_KEY="${credentials[0]}"
    export AWS_SESSION_TOKEN="${credentials[1]}"
    export AWS_ACCESS_KEY_ID="${credentials[2]}"
  fi
}

function get_plan_name() {
    echo "tf-plan-${BUILD_NUMBER:=LOCAL}.plan"
}

function set_terraform_variables() {
    declare old_ifs="$IFS"
    variables=(
      -var-file "$latest_amis"
      -var-file "$environments_tfvars"
      -var-file "$vpc_tfvars"
      -var-file "$waf_rule_tfvars"
      -var-file "$asg_capacities_tfvars"
      -var "aws-region=${AWS_DEFAULT_REGION}"
      -var "aws-account-id=${AWS_ACCOUNT_ID}"
    )

    TARGET_VPC_ONLY=${TARGET_VPC_ONLY:-false}
    MODULES=${MODULES:-}

    if [[ "${TARGET_VPC_ONLY}" = true ]]; then
      echo "Targeting only vpc"
      variables=(-target module.vpc -target module.vpc_route_tables_private_app_subnets -target module.vpc_route_tables_private_rds_subnets ${variables[@]})
    elif [[ -n "$MODULES" ]];then
      old_ifs="$IFS"
      IFS=" "
      for module in $MODULES; do
        echo "Targeting resource address $module"
          variables=(-target $module ${variables[@]})
      done
      IFS="$old_ifs"
    fi
}

function terraform_plan() {
    local latest_amis=${1:-}
    local vpc_tfvars=${2:-}
    local plan=${3:-}
    local planParam
    local destroyParam
    local retCode
    local retCodeFile
    local terraformOutputFile
    plan=${plan:-$(get_plan_name)}
    set +e

    if [[ "$plan" = "-destroy" ]]; then
        planParam="-out=$(get_plan_name)"
        destroyParam="-destroy"
    else
        planParam="-out=$plan"
        destroyParam=""
    fi

    terraformOutputFile="$(mktemp)"
    retCodeFile="$(mktemp)"
    #shellcheck disable=SC2068,SC2086
    ( terraform plan \
            $planParam \
            $destroyParam \
            -detailed-exitcode \
            "${variables[@]}" 
        echo "$?" > "$retCodeFile" ) \
        | tee "$terraformOutputFile" \
        && echo "******** landscape output:" \
        && landscape --trace < "$terraformOutputFile"
    retCode="$(cat "$retCodeFile")"
    rm -f "$terraformOutputFile" "$retCodeFile"
    return "$retCode"
}

function should_apply() {
    local result=${1:-0}
    case "$result" in
        0)
            echo "plan was unchanged"
            ;;
        1)
            echo "plan had an error"
            ;;
        2)
            # 2 exit code means there are changes to apply, see https://www.terraform.io/docs/commands/plan.html
            # At this point, we want to wait for approval. Ideally, we archive the plan file from this build and have a
            # separate job that would have to be manually run to actually implement infrastructure changes. For right now
            # in local testing, just ask to apply.
            if [[ -n "${BUILD_NUMBER:-}" ]]; then
                # If we are running in Jenkins, full speed ahead, apply the plan
                echo "true"
            else
                # only ask for approval in interactive shells
                read -r -p "Apply Plan? [y/N] " response
                case $response in
                    [yY][eE][sS]|[yY])
                        echo "true"
                        ;;
                    *)
                        echo "false"
                        ;;
                esac
            fi
            ;;
        *)
            echo "unknown reason"
            ;;
    esac
}

function terraform_apply() {
    local latest_amis=${1:-}
    local vpc_tfvars=${2:-}
    local plan=${3:-}
    local result
    if [[ -f "$plan" ]] && [[ -n "${BUILD_NUMBER:-}" ]]; then
        # If we are running in Jenkins and we have a plan continue
        result=2 # same as when terraform plan yields a plan
    else
        plan=${plan:-$(get_plan_name)}
        set +e
        terraform_plan "$latest_amis" "$vpc_tfvars" "$plan"
        result=$?
        echo "Result: $result"
        set -e
    fi
    apply=$(should_apply $result)
    if [[ "$apply" == "true" ]]; then
        # Check to make sure WAF WebACL is in place
        manage-waf::check
        # Suspend auto scaling processes on all ASGs
        manage-asg::suspend-all-processes
        # In case of failure, ensure the processes are resumed
        trap "manage-asg::resume-all-processes && exit 1" EXIT

        terraform apply "$plan"

        # Clear the trap-s handler as Terraform finished successfully.
        trap - EXIT
        # Resume auto scaling processes on all ASGs
        manage-asg::resume-all-processes

        if [[ "${TARGET_VPC_ONLY}" != true ]] && [[ -z "${MODULES}" ]]; then
            echo "Uploading Elasticache credentials to S3..."
            upload-elasticache-creds

            echo "Uploading AuroraCluster credentials to S3..."
            upload-aurora-cluster-creds

            echo "Uploading EFS targets to S3..."
            upload-efs-target edocs_mount_target
        fi

        # Associate any alb with a "associate_with_waf" tag to the WAF WebACL
        manage-waf::associate

        echo "Done!"
    else
        echo "Not applying plan, because: $apply"
    fi
}

function terraform_import() {
  #shellcheck disable=SC2048,SC2086
  terraform import "${variables[@]}" $*
}

function terraform_taint() {
  #shellcheck disable=SC2048,SC2086
  # The "taint" command has a different syntax from most other terraform commands
  # See: https://github.com/hashicorp/terraform/issues/11570
  terraform taint "${variables[@]}" $*
}

function terraform_state() {
  #shellcheck disable=SC2048,SC2086
  terraform state $*
}

function terraform_destroy() {
    local latest_amis=${1:-}
    local vpc_tfvars=${2:-}
    local force=${3:-}
    #shellcheck disable=SC2086,SC2068
    terraform destroy $force "${variables[@]}"
}

function get_config() {
    local latest_amis=${1:-}
    local vpc_tfvars=${2:-}
    local environments_tfvars=${3:-}
    local waf_rule_tfvars=${4:-}

    local latest_amis_s3_obj="s3://${BASE_TERRAFORM_STATE_BUCKET}/shared/${latest_amis}"
    local vpc_id_s3_obj="s3://${BASE_TERRAFORM_STATE_BUCKET}/shared/${vpc_tfvars}"
    local environments_s3_obj="s3://${BASE_TERRAFORM_STATE_BUCKET}/shared/${environments_tfvars}"
    local waf_rule_s3_obj="s3://${BASE_TERRAFORM_STATE_BUCKET}/shared/${waf_rule_tfvars}"
    aws-s3-copy-if-exists "$latest_amis_s3_obj" .
    aws-s3-copy-if-exists "$vpc_id_s3_obj" .
    aws-s3-copy-if-exists "$environments_s3_obj" .
    aws-s3-copy-if-exists "$waf_rule_s3_obj" .
}

function test_prerequisites() {
    local latest_amis=${1:-}
    local vpc_tfvars=${2:-}
    local environments_tfvars=${3:-}
    local waf_rule_tfvars=${4:-}
    if [[ ! -f "$DIR/$latest_amis" ]]; then
        echo "Fatal: you must run packer to create $latest_amis before planning"
        return 1
    fi
    if [[ ! -f "$DIR/$vpc_tfvars" ]]; then
        local vpc_id
        local rt_id
        vpc_id=$(aws ec2 describe-subnets --query 'Subnets[0].VpcId' --output text)
        rt_id=$(aws ec2 describe-route-tables --query 'RouteTables[0].RouteTableId' --output=text)
        echo "Warning: creating stub $vpc_tfvars, please check that this contains correct values."
        cat > "$DIR/$vpc_tfvars" <<EOF
# This needs to be the main or default VPC in the account
corp_vpc_id = "$vpc_id"
# This needs to be the default routing table for the main VPC in the account
corp_rt_id_1 = "$rt_id"
# This is for future expansion, this is unused currently
corp_rt_id_2 = "rtb-SSSSSSSS"
EOF
    fi
    if [[ ! -f "$DIR/$environments_tfvars" ]]; then
        cat > "$DIR/$environments_tfvars" <<EOF
environments = [
    "qa",
    "staging"
]
EOF
    fi
    for package in $packages; do
        ensure_installed "$package";
    done
}

function terraform_init() {
    # There is no way to force a copy operation with new backend config.
    # Tracking https://github.com/hashicorp/terraform/issues/12921
    # So for now just forcibly remove .terraform directory and initialize each time.
    # All state is stored in the bucket. Eventually we will be able to just do
    # terraform init -backend-config "bucket=${BASE_TERRAFORM_STATE_BUCKET} -force-copy"
    for bucket in "$BASE_TERRAFORM_STATE_BUCKET" "$APP_CONFIG_BUCKET"; do
        set +e
        if ! aws s3 ls "$bucket" > /dev/null 2>&1; then
            aws s3 mb "s3://$bucket"
            aws s3api put-bucket-versioning  --bucket "${bucket}" \
                --versioning-configuration Status=Enabled
        fi
        set -e
    done
    rm -rf "$DIR/.terraform"
    terraform init -get -backend-config "bucket=${BASE_TERRAFORM_STATE_BUCKET}" -backend-config "region=$AWS_DEFAULT_REGION" -force-copy
}

########### main script for run_terraform.sh

# Crack command line parameters out
verb=${1:-}
plan=${2:-}
# Shift at most 2 parameters out
# Thanks Stack Overflow for the max fn https://stackoverflow.com/a/10415158/424301
shift $(($# > 2 ? 2 : $#))

declare packages="ruby
jq
wget
unzip"

export PATH="$PATH:$HOME/tools/"

cd "$DIR"
if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
    echo "AWS Access key detected: $AWS_ACCESS_KEY_ID"
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
fi
ensure_awscli
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
# Thanks Stack Overflow http://stackoverflow.com/a/40903752
declare AWS_ACCOUNT_ID
AWS_ACCOUNT_ID=$(get_aws_account_id)
echo "Targeting region $AWS_DEFAULT_REGION in AWS Account $AWS_ACCOUNT_ID"

declare BASE_TERRAFORM_STATE_BUCKET="unmanaged-tf-state-${AWS_ACCOUNT_ID}"
declare APP_CONFIG_BUCKET="unmanaged-app-config-${AWS_ACCOUNT_ID}"
declare latest_amis="latest-amis-$AWS_ACCOUNT_ID.tfvars"
declare vpc_tfvars="vpc-id-$AWS_ACCOUNT_ID.tfvars"
declare environments_tfvars="environments-$AWS_ACCOUNT_ID.tfvars"
declare waf_rule_tfvars="waf-rule-ids-${AWS_ACCOUNT_ID}.tfvars"
declare asg_capacities_tfvars="asg-capacities-${AWS_ACCOUNT_ID}.json"
declare variables

ensure-branch-protect
get_config "$latest_amis" "$vpc_tfvars" "$environments_tfvars" "$waf_rule_tfvars"
test_prerequisites "$latest_amis" "$vpc_tfvars" "$environments_tfvars" "$waf_rule_tfvars"
ensure_terraform_installed
ensure_terraform_version
ensure_terraform_landscape
set-role-variables
manage-asg::generate-tfvars
set_terraform_variables
terraform_init
case "$verb" in
"plan")
    set +e
    terraform_plan "$latest_amis" "$vpc_tfvars" "$plan"
    result=$?
    case $result in
        0)
            echo "No changes planned."
            ;;
        1)
            echo "Error running terraform plan..."
            exit 1
            ;;
        2)
            echo "Changes planned OK - saved to $(get_plan_name)"
            exit 0
            ;;
        *)
            echo "Unknown terraform exit status: $result"
            exit "$result"
            ;;
    esac
    set -e
    ;;
"apply")
    terraform_apply "$latest_amis" "$vpc_tfvars" "$plan"
    ;;
"destroy")
    terraform_destroy "$latest_amis" "$vpc_tfvars" "$plan"
    ;;
"import")
    #shellcheck disable=SC2048,SC2086
    terraform_import $*
    ;;
"state")
    #shellcheck disable=SC2048,SC2086
    terraform_state "$plan" $*
    ;;
"taint")
    #shellcheck disable=SC2048,SC2086
    terraform_taint "$plan" $*
    ;;
"clean")
    read -r -p "This will clean (delete!) the local Terraform cache, proceed? [y/N] " response
        case $response in
            [yY][eE][sS]|[yY])
                rm -rf "$DIR/.terraform"
            ;;
        esac
    ;;
*)
    echo "$0: Unknown command: '$verb' - did you mean to do '$0 plan'?"
    exit 1
    ;;
esac
