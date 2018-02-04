#!/usr/bin/env bash


# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
. "$COMMON_DIR/aws/manage-aws.sh"

# If the environment file exists, let's source it.
# Thanks Stack Overflow http://stackoverflow.com/a/246128/424301
env_file="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../env.sh"
if [ -f "$env_file" ]; then
    #shellcheck disable=1090
    . "$env_file"
else
    # In the least, if the .env file does not exists
    # Specify a default region.
    export AWS_DEFAULT_REGION="us-east-1"
fi

function declare_target () {
    echo "Targeting region $AWS_DEFAULT_REGION in AWS Account $(get_aws_account_alias) ($(get_aws_account_id))"
}

function num_in_service() {
    local asg
    asg=${1:-$ASG_NAME}
    aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "${asg}" \
        | jq -r '.AutoScalingGroups[0].Instances | map(select(.LifecycleState | contains("InService"))) | length'
}

function parse_build_number() {
    # Parses a jenkins build number from the URL
    local build_url
    build_url="${1:-}"
    # Credits: https://www.cyberciti.biz/faq/unix-linux-bash-split-string-into-array/
    OIFS="$IFS"
    IFS='/'
    read -r -a build_url_parts <<< "${build_url}"
    IFS="$OIFS"
    echo "${build_url_parts[${#build_url_parts[@]} - 1]}"
}

# Verify if jq is installed, if not install it
function ensure_jq () {
    if ! which jq> /dev/null; then
        sudo yum -q -y install jq
    fi
}

# Verify if zip is installed, if not install it
function ensure_zip () {
    if ! which zip> /dev/null; then
        sudo yum -q -y install zip
    fi
}

# Verify if unzip is installed, if not install it
function ensure_unzip () {
    if ! which unzip> /dev/null; then
        sudo yum -q -y install unzip
    fi
}

# Verify if terraform-landscape is installed, if not install it
# Reference: https://github.com/coinbase/terraform-landscape
function ensure_terraform_landscape () {
    if ! which landscape > /dev/null; then
        if ! which pip > /dev/null; then
            sudo yum -q -y install python-pip
        fi
        if ! which gem > /dev/null; then
            sudo pip install gem
        fi
        gem install --no-rdoc --no-ri terraform_landscape || echo "Landscape install failed!"
        export PATH="$PATH:~/bin/"
    fi
}

# Verify if aws cli is installed, if not install it
function ensure_awscli () {
    if ! which aws > /dev/null; then
        if ! which pip > /dev/null; then
            sudo yum -q -y install python-pip
        fi
        sudo pip install awscli
    fi
    # Ensure that there is a region configured
    local region
    region=$(get_aws_region)
    if [[ ! -f ~/.aws/config ]]; then
        mkdir -p ~/.aws
        cat > ~/.aws/config <<EOF
[default]
region = $region
EOF
    fi
}

function ensure_installed() {
    package=${1:-}
    set +e
    if ! which "$package" > /dev/null 2>&1; then
        set -e
        echo "Installing $package..."
        sudo yum -y -q install "$package"
    fi
    set -e
}

function scroll_impl () {
    local text
    text="${1:-}"
    local scroller
    scroller="${2:-}"
    local lines
    lines=$(wc -l <<<"$text")
    if [[ $lines -gt 0 ]]; then
        #shellcheck disable=SC2034
        for line in $(seq 1 "$lines"); do
            #shellcheck disable=SC2059
            printf "$scroller"
        done
    fi
}

function rewind () {
    local text
    text="${1:-}"
    scroll_impl "$text" "\033[F"
    scroll_impl "$text" "                                                 \n"
    scroll_impl "$text" "\033[F"
}

function scrolldown () {
    scroll_impl "${1:-}" "\n"
}


# Retries a command a with backoff.
#
# The retry count is given by ATTEMPTS (default 5), the
# initial backoff timeout is given by TIMEOUT in seconds
# (default 1.)
#
# Successive backoffs double the timeout.
# Beware of set -e killing your whole script!
#
# Thanks to Coderwall
#   --> https://coderwall.com/p/--eiqg/exponential-backoff-in-bash
function try_with_backoff {
    local max_attempts=${ATTEMPTS-6}
    local timeout=${TIMEOUT-1}
    local attempt=0
    local exitCode=0

    while [[ $attempt < $max_attempts ]]
    do
        "$@"
        exitCode=$?

        if [[ $exitCode == 0 ]]
        then
            break
        fi

        echo "Failure! Retrying in $timeout.." 1>&2
        sleep "$timeout"
        attempt=$(( attempt + 1 ))
        timeout=$(( timeout * 2 ))
    done

    if [[ $exitCode != 0 ]]
    then
		#shellcheck disable=SC2145
        echo "You've failed me for the last time! ($@)" 1>&2
    fi

    return $exitCode
}

declare -i TF_VERSION_MAJOR=0
declare -i TF_VERSION_MINOR=11
declare -i TF_VERSION_BUILD=1
declare TERRAFORM_VERSION="${TF_VERSION_MAJOR}.${TF_VERSION_MINOR}.${TF_VERSION_BUILD}"

# Terraform version check.
function verify_terraform_version() {
    local CURRENT_VERSION=${1:-}
    set +e
    declare VERSION_PATTERN="Terraform v([0-9]+)\.([0-9]+)\.([0-9]+)"

    if [[ $CURRENT_VERSION =~ $VERSION_PATTERN ]]; then
        if [[ "${BASH_REMATCH[1]}" -ne $TF_VERSION_MAJOR ]] || [[ "${BASH_REMATCH[2]}" -ne $TF_VERSION_MINOR ]] \
            || [[ "${BASH_REMATCH[3]}" -ne $TF_VERSION_BUILD ]]; then
            echo "an unsupported version, ${CURRENT_VERSION}"
        else
            echo "supported"
        fi
    else
        echo "an unknown version"
    fi
    set -e
}

function ensure_terraform_installed () {
    local version
    local versionCheck
    local terraformFile
    terraformFile="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    set +e
    version=$(terraform version | head -n 1)
    set -e
    versionCheck=$(verify_terraform_version "$version")
    if [[ -z "$(which terraform)" ]] || [[ "$versionCheck" != "supported" ]]; then
       mkdir -p "$HOME/tools"
       rm -f "${HOME}/tools/terraform"
       # Ensure supporting tools are installed for CentOS
       wget -nv \
            -O "$terraformFile" \
            "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/$terraformFile"
       unzip "$terraformFile" -d "${HOME}/tools/"
       rm "$terraformFile"
       chmod +x "${HOME}/tools/terraform"
    fi
}

function ensure_terraform_version () {
    local version
    local versionCheck
    set +e
    version=$(terraform version | head -n 1)
    set -e
    versionCheck=$(verify_terraform_version "$version")
    if [[ "$versionCheck" == "supported" ]]; then
        echo "Terraform version verified: $version"
    else
        echo "You're using $versionCheck but only ${TERRAFORM_VERSION} is supported. Exiting."
        return 1
    fi
}
