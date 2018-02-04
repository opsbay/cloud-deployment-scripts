#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

#. /etc/profile.hobsons
# shellcheck disable=2154
true

set -x

EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AWS_ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | awk -F '"' '/accountId/ { print $4 }')
ENVIRONMENT=$(aws ec2 describe-instances --instance-ids "${EC2_INSTANCE_ID}" --region us-east-1 | jq -r '.Reservations[].Instances[].Tags[] | select(.Key=="Env") | .Value')
NODE=$(aws ec2 describe-instances --instance-ids "${EC2_INSTANCE_ID}" --region us-east-1 | jq -r '.Reservations[].Instances[].Tags[] | select(.Key=="index") | .Value')
NODE_COUNT=3 # Be better than this.
S3_BUCKET="s3://unmanaged-app-config-${AWS_ACCOUNT_ID}"
S3_MONGO_CONFIG_PATH="${S3_BUCKET}/${ENVIRONMENT}/edocsmongo"

MONGODB_DBPATH=/var/lib/mongo

function setup-ebs-volume() {
  DEVICE="${1:-}"
  parted --script "${DEVICE}" \
    mklabel gpt \
    mkpart primary 0% 100%
  sleep 10
  if [[ ! $(file -sL "${DEVICE}1" | grep XFS) ]]; then
    mkfs.xfs "${DEVICE}1"
    sleep 10
  fi
}

function check-or-create-mount() {
  DEVICE="${1:-}"
  MOUNT_POINT="${2:-}"

  DEVICE="${1:-}"
  while [[ ! -b "${DEVICE}" ]]; do
    echo "Waiting for ${DEVICE}..."
    sleep 10
  done

  set +e
  mountpoint -q "${MOUNT_POINT}"
  EXISTS_RESULTS=$?
  set -e

  if [[ "$EXISTS_RESULTS" -eq 1 ]]; then
    echo "${MOUNT_POINT} Does Not Exist."
    mkdir -p "${MOUNT_POINT}"
    setup-ebs-volume "${DEVICE}"
    mount "${DEVICE}1" "${MOUNT_POINT}"
    sleep 5
  fi

  restorecon -r "${MOUNT_POINT}"
}

function update-config() {
  aws s3 cp "${S3_MONGO_CONFIG_PATH}/mongod.keyfile" /etc/mongod.keyfile
  aws s3 cp "${S3_MONGO_CONFIG_PATH}/mongod.conf" /etc/mongod.conf

  chown mongod:mongod /etc/mongod.conf
  chmod 400 /etc/mongod.keyfile
  chown mongod:mongod /etc/mongod.keyfile

  systemctl restart mongod
  systemctl status mongod || \
    echo "Seems like mongod is not running! Check /var/log/mongo/mongod.log or /var/log/audit/audit.log more likely."
}

if [[ ! $(semodule -l | grep -i "mongod.1.0") ]]; then
  aws s3 cp "${S3_MONGO_CONFIG_PATH}/mongod.te" .
  checkmodule -M -m -o mongod.mod mongod.te
  semodule_package -o mongod.pp -m mongod.mod
  semodule -i mongod.pp
  semanage port -a -t mongod_port_t -p tcp 27017 || true
  setenforce 0
  firewall-cmd --add-port=27017/tcp --permanent
  firewall-cmd --reload
  setenforce 1
fi

# Tune OS for Mongo

cat > "/etc/init.d/disable-transparent-hugepages" << 'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          disable-transparent-hugepages
# Required-Start:    $local_fs
# Required-Stop:
# X-Start-Before:    mongod mongodb-mms-automation-agent
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Disable Linux transparent huge pages
# Description:       Disable Linux transparent huge pages, to improve
#                    database performance.
### END INIT INFO

case \${1} in
  start)
    if [ -d /sys/kernel/mm/transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/transparent_hugepage
    elif [ -d /sys/kernel/mm/redhat_transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/redhat_transparent_hugepage
    else
      return 0
    fi

    echo 'never' > \${thp_path}/enabled
    echo 'never' > \${thp_path}/defrag

    unset thp_path
    ;;
esac
EOF

chmod 755 /etc/init.d/disable-transparent-hugepages
chkconfig --add disable-transparent-hugepages

# Run once so we don't have to reboot
service disable-transparent-hugepages start

###################################
# set rlimits
###################################

cat > "/etc/security/limits.d/99-mongodb-nproc.conf" << EOF
mongod    soft    nproc    64000
mongod    hard    nproc    64000
mongod    soft    fsize    unlimited
mongod    hard    fsize    unlimited
mongod    soft    cpu      64000
mongod    hard    cpu      64000
mongod    soft    nofile   64000
mongod    hard    nofile   64000
EOF

#Check mount points and mount volumes
check-or-create-mount "/dev/xvdg" "${MONGODB_DBPATH}"
check-or-create-mount "/dev/xvdh" "${MONGODB_DBPATH}/journal"
check-or-create-mount "/dev/xvdi" "/var/log/mongodb"

# setup mongodb repository so that mongodb can be YUMed
cat > "/etc/yum.repos.d/mongodb-org-3.2.repo" << EOF
[mongodb-org-3.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/3.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.2.asc
EOF

# install packages
yum install -y mongodb-org-3.2.17 || \
  echo "Unable to install mongodb"

# update permissions
chown -R mongod:mongod "${MONGODB_DBPATH}" || \
  echo "Unable to change ownership of mongodb directory ${MONGODB_DBPATH} to mongod"

update-config


# check if admin credentials already exist
aws s3 cp "${S3_MONGO_CONFIG_PATH}/credentials" .

MONGODB_ADMIN_USERNAME=""
MONGODB_ADMIN_PASSWORD=""
source credentials

set +e
rs_status_response=$(mongo --quiet \
  -u "${MONGODB_ADMIN_USERNAME}" \
  -p "${MONGODB_ADMIN_PASSWORD}" \
  --eval "JSON.stringify(rs.status())")
rs_status_rc=$?
set -e

if [[ ! "${rs_status_rc}" -eq "0" ]]; then
  if [[ $(mongo --quiet --eval "JSON.stringify(rs.status())" | jq -r .code) == "94" ]]; then
    # Error Code 94 is "NotYetInitialized"
    RS_INIT_CONFIG="rs.initiate({_id : \"${ENVIRONMENT}\", members: [{ _id : 0, host : \"tf-mongo-${ENVIRONMENT}-00.local.naviance.com:27017\" }, { _id : 1, host : \"tf-mongo-${ENVIRONMENT}-01.local.naviance.com:27017\" }, { _id : 2, host : \"tf-mongo-${ENVIRONMENT}-02.local.naviance.com:27017\" }]});"
    RS_INIT_CODE=$(mongo --quiet --eval "${RS_INIT_CONFIG}" "admin" | jq .code)
    while [[ "${RS_INIT_CODE}" -ne "23" ]]; do
      echo "Waiting for nodes..."
      sleep 10
      RS_INIT_CODE=$(mongo --quiet --eval "${RS_INIT_CONFIG}" "admin" | jq .code)
      if [[ "${RS_INIT_CODE}" == "null" ]]; then
        RS_INIT_CODE=23
      fi
    done
    # The rest needs to be run on the primary node.
    if [[ $(mongo --quiet --eval "JSON.stringify(db.isMaster());" | jq -r .ismaster) == "true" ]]; then
      mongo \
        --quiet \
        --eval "db.createUser({ user: \"${MONGODB_ADMIN_USERNAME}\", pwd: \"${MONGODB_ADMIN_PASSWORD}\", roles: [ \"userAdminAnyDatabase\",\"dbAdminAnyDatabase\",\"clusterAdmin\",\"readWriteAnyDatabase\"]})"
      mongo \
        --quiet \
        -u "${MONGODB_ADMIN_USERNAME}" \
        -p "${MONGODB_ADMIN_PASSWORD}" \
        --eval "db.createCollection(\"${MONGODB_DBNAME}\")"
      mongo \
        --quiet \
        -u "${MONGODB_ADMIN_USERNAME}" \
        -p "${MONGODB_ADMIN_PASSWORD}" \
        --eval "db.createUser({user: \"${MONGODB_USERNAME}\", pwd: \"${MONGODB_PASSWORD}\",roles: [{ role: \"readWrite\", db: \"${MONGODB_DBNAME}\" }]})"
    fi
  fi
fi

# Don't leave this on the FS
rm credentials