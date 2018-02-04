#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

case $(awk 'NR==1{print $1}' /etc/*release) in
        CentOS )
               echo "CentOS detected, installing redhat-lsb-core"
               set +e
               sudo yum -y -q install redhat-lsb-core
               set -e
        ;;
esac

case $(lsb_release -si) in
        CentOS )
                set +e
                echo "Installing NFS"
                if ! rpm -qa | grep portmap; then
                    sudo yum -y -q install portmap nfs-utils
                fi
                set -e
        ;;
        Ubuntu )
                # This could fail, and we want to continue, so temporarily suspend exiting on failure
                set +e
                echo "Installing NFS"
                if ! dpkg-query -W portmap; then
                        sudo apt-get -qq update
                        sudo apt-get -qq install -y portmap nfs-common
                fi
                set -e
        ;;
        * )
                echo "Not Supported"
        ;;
esac

