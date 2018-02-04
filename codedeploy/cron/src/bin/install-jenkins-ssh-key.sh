#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Enable to see every shell command
#set -x

KEYFILE="/home/centos/.ssh/authorized_keys"
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDaiGzURTWTdD8tWq1w0AErfFnzUqqV000c8P9EQ8i6PAcpowz9P1YHRHq+1ttvU+7IpYrA8IdVKdwTr5kM6XO7ws9VujVcjl04YFfF94rrX9B3Z4D5NOGnb8dWL3LwObH0Iik9BaBmeOMA2tSfL8Y4ON8WB2cNSBJeYO+DIaQH7syJZ9CGd9BGQLmfklzCeBMbzwwMVfuLbHw0hVtY5IA9BNpWjiI5hIlFIyZT0IAhN4tCfDAMF2yqSs0/zbyVxqNv/WUnkr6YrOn3kPQOCBgewvh6+S9TowUCPhyto4QTlFxv9IjiDj4ti8LAeLQ33eB5gDxSXGyBrWVrPVl+CkOB dev-centos-cron"

if ! grep -q "${SSH_PUBLIC_KEY}" "${KEYFILE}"; then
    echo "${SSH_PUBLIC_KEY}" >>  "${KEYFILE}"
    # on the off chance that this operation created the file
    chown centos.centos "${KEYFILE}"
    chmod 600 "${KEYFILE}"
fi