#!/bin/bash
set -euo pipefail

IAM_USER_NAME=learnapi
INSTALL_DIR=/opt/naviance/learnapi

if getent passwd "${IAM_USER_NAME}" > /dev/null ; then
  # nothing to do as user already exists
  echo "Skipping Create User as user '${IAM_USER_NAME}' already exists"
else
  echo "Creating user: ${IAM_USER_NAME}"
  if ! useradd -m "${IAM_USER_NAME}"; then
    echo "Unable to provision user account as: useradd -m '${IAM_USER_NAME}'"
    exit 1
  fi
  echo "Created user: ${IAM_USER_NAME}"
fi

mkdir -p        $INSTALL_DIR/logs
touch           $INSTALL_DIR/logs/StudentService.log
touch           $INSTALL_DIR/logs/StudentService-error.log
chown learnapi. $INSTALL_DIR/logs/*
chgrp learnapi  $INSTALL_DIR/logs
chmod g+w       $INSTALL_DIR/logs

firewall-cmd --add-port=6060/tcp --permanent
firewall-cmd --add-port=6064/tcp --permanent

firewall-cmd --reload

mkdir -p "${INSTALL_DIR}"
