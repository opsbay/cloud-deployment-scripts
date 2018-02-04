#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

upgrade=/bin/false

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
                if ! rpm -qa | grep ansible; then
                        if "$upgrade"; then
                            echo "Upgrading all packages to latest"
                            sudo yum -y -q update
                        fi
                        echo "Installing epel-release"
                        sudo yum -y -q install epel-release
                        echo "Installing Ansible"
                        sudo yum -y -q install ansible
                        ansible --version
                fi
                set -e
        ;;
        Ubuntu )
                # This could fail, and we want to continue, so temporarily suspend exiting on failure
                set +e
                if ! dpkg-query -W ansible; then
                        # Add PPA for Ansible >= 2
                        sudo apt-get -qq install -y software-properties-common
                        sudo apt-add-repository ppa:ansible/ansible
                        sudo apt-get -qq update
                        if "$upgrade"; then
                            echo "Upgrading all packages to latest"
                            sudo apt-get -qq -y upgrade
                        fi
                        echo "Installing Ansible"
                        sudo apt-get -qq install -y ansible
                fi
                set -e
        ;;
        * )
                echo "Not Supported"
        ;;
esac

# Create directories needed for packer provisioner to use.
#
# Requred for CentOS 7 since /tmp gets blown away.
#
# Nice to have on other distributions too so we do not pollute
# the home directory.
ansible_dir="/opt/packer-provisioner-ansible-local"
sudo mkdir -p "$ansible_dir/bin"
sudo chown -R "${USER}:${USER}" "$ansible_dir"

