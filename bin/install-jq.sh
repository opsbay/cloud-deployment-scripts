#!/usr/bin/env bash
set -uo pipefail
os=$(uname -s)

if ! which jq> /dev/null; then
    case $os in
        Darwin)
            brew install jq
            ;;
        Linux)
            # Assumes CentOS 7
            if ! rpm -q epel-release; then
               sudo yum -y install epel-release
            fi
            if ! rpm -q jq; then
                sudo yum -y install jq
            fi
            ;;
        *)
            echo "ERROR: Unknown OS $os"
            exit 1
            ;;
    esac
fi