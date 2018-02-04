#!/usr/bin/env bash
set -uo pipefail
os=$(uname -s)
case $os in
    Darwin)
        brew install shellcheck
        ;;
    Linux)
        # Assumes CentOS 7
        if ! rpm -q epel-release; then
           sudo yum -y install epel-release
        fi
        if ! rpm -q ShellCheck; then
            sudo yum -y install ShellCheck
        fi
        ;;
    *)
        echo "ERROR: Unknown OS $os"
        exit 1
        ;;
esac
