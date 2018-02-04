#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

UPDATE_SCRIPT_PATH="/usr/local/sbin/mongo-cluster_bootstrap-updater.sh"
UPDATE_SCRIPT=$(cat <<EOF
#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

{ 
    echo 'Attempting to download override mongo bootstrap script...'
    aws s3 cp "s3://unmanaged-app-config-${awsAccountId}/${environment}/${name}-mongo/mongo-cluster_bootstrap.sh" /usr/local/sbin/mongo-cluster_bootstrap.sh
} || {
    # Fallback to downloading the default mongo bootsrap script...
    echo 'Falling back to default mongo bootstrap script...'
    aws s3 cp "s3://unmanaged-app-config-${awsAccountId}/mongo-cluster/mongo-cluster_bootstrap.sh" /usr/local/sbin/mongo-cluster_bootstrap.sh
}

chmod +x /usr/local/sbin/mongo-cluster_bootstrap.sh
/usr/local/sbin/mongo-cluster_bootstrap.sh
EOF
)

echo "$UPDATE_SCRIPT" > "$UPDATE_SCRIPT_PATH"
chmod +x "$UPDATE_SCRIPT_PATH"
echo "$UPDATE_SCRIPT_PATH" >> /etc/rc.local

# Execute the bootstrap updater script manually for this first boot, since it's too late to use rc.local.
sh "$UPDATE_SCRIPT_PATH"