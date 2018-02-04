#!/usr/bin/env bash

Out.blue "Running: ${BASH_SOURCE[0]}"

DIR="$BASEDIR/tasks"

declare -i access_key_count
declare username
declare access_key_out

create_user() {
    local username
    local cd_user_arn
    username="$1"

    # Create an IAM user that the on-premises instance will use to authenticate and interact with AWS CodeDeploy.
    # And grab the ARN.
    cd_user_arn=$(aws iam create-user \
        --user-name "$username" \
        --query 'User.Arn' --output text)
    echo "$cd_user_arn"
}

set +e
# If user doesn't exit, create him.
# We also get the ARN of the user.
existing_user=$(aws iam get-user \
    --user-name "$username" \
    --output text --query 'User.Name')
echo "Existing User: $existing_user"
set -e

if [[ -z "$existing_user" ]]; then
    # User doesn't exist, so we create him. 
    Out.blue "User doesn't exist. Creating IAM user: $username"
    cd_user_arn=$(create_user "$username")
else
    # User exists, get the existing users ARN.
    Out.blue "User $username already exists."
    cd_user_arn=$(aws iam get-user \
        --user-name "$username" \
        --query 'User.Arn' \
        --output text)
fi

# We must make sure the user has only one access key.
# We grab the access key(s)...
access_keys=$(aws iam list-access-keys \
    --user-name "$username" \
    --query 'AccessKeyMetadata[*].AccessKeyId' \
    --output text)
access_key_count=$(wc -w <<<"$access_keys")
echo "Access key count: $access_key_count"

function ensure_access_key_count () {
    local desired_count
    desired_count=${1:-1}
    if [[ $access_key_count -gt $desired_count ]]; then
        Out.blue "Excess access keys detected for the user $username"
        Out.blue "($desired_count expected, $access_key_count detected)"
        Out.blue "so we are deleting the excess keys..."
        # Get all the access keys and delete everything except the first listed one.
        while read -r delete_key; do
            # Delete the excess keys.
            Out.blue "Deleting key: $delete_key"
            aws iam delete-access-key \
                --user-name "$username" \
                --access-key-id "$delete_key"
        done <<<"$access_keys"
    fi
}

ensure_access_key_count 1
# Stash the keys in a file in the home directory
CD_USER_KEYS="$HOME/.aws-cd-user"
if [[ -f "$CD_USER_KEYS" ]]; then
    #shellcheck disable=SC1090
    . "$CD_USER_KEYS"
else
    # If there are no access keys stashed, 
    # we delete all the remaining keys and create a new one,
    # then stash it in a file...
    ensure_access_key_count 0
    Out.blue "Creating access key for the user $username"
    access_key_out=$(aws iam create-access-key \
        --user-name "$username" \
        --query 'AccessKey' \
        --output text)
    cd_user_access_key=$(echo "$access_key_out" | awk '{print $1}')
    cd_user_secret_key=$(echo "$access_key_out" | awk '{print $3}')
    cat > "$CD_USER_KEYS" <<EOF
cd_user_access_key=$cd_user_access_key
cd_user_secret_key=$cd_user_secret_key
EOF
fi

# We grab the AWS account id which we need for assigning permissions.
# Thanks Stack Overflow https://stackoverflow.com/a/40121084/424301
AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
    --output text \
    --query 'Account')

# Assign policy to user.
# Edit the policy file to add the AWS account ID.
Out.green "Editing policy document"
cp -f "$DIR/../CodeDeploy-OnPrem-Permissions.json" "/tmp/CodeDeploy-OnPrem-Permissions-edited.json"
sed -i.bak -e "s/{{ AWS_ACCOUNT_ID }}/${AWS_ACCOUNT_ID}/g" "/tmp/CodeDeploy-OnPrem-Permissions-edited.json"
rm -f "/tmp/CodeDeploy-OnPrem-Permissions-edited.json.bak"

# We now assign permissions to the user.
Out.blue "Assigning policy to user"
#shellcheck disable=SC2154
aws iam put-user-policy \
    --user-name "$username" \
    --policy-name "$policy_name" \
    --policy-document "file:///tmp/CodeDeploy-OnPrem-Permissions-edited.json"
