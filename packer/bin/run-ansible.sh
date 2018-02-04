#!/usr/bin/env bash
set -euo pipefail
region="${1:-us-east-1}"
playbook="${2:-site.yml}"
splunkfwd="${3:-127.0.0.0}"

echo "Running ansible playbook:$playbook region: $region"

ansible-playbook \
    -i "localhost," \
    -c local "/vagrant/packer/ansible/$playbook" \
    --extra-vars "aws_default_region=$region splunk-forwarder=$splunkfwd"
