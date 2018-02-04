#!/usr/bin/env bash
#
# Cloud init script for db-control server
#

function install_mysql {
    # Add the mysql-community repo
    yum install -y -q http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
    # Install the mysql client
    yum install -y -q mysql-community-client
}

function install_mongodb {
    # Add mongodb repo
    cat > "/etc/yum.repos.d/mongodb-org-3.2.repo" << EOF
[mongodb-org-3.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/3.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.2.asc
EOF
# install mongodb tools and shell
yum install -y -q mongodb-org-tools mongodb-org-shell
}

function install_percona_toolkit {
    # Add percona repo
    yum install -y -q http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
    # Install percona-toolkit
    yum install -y -q percona-toolkit
}

function install_python_modules {
    # Upgrade pip
    pip install --upgrade pip
    # Install required python modules
    pip install --upgrade virtualenv boto pymongo
}

function install_other_dependencies {
    yum install -y -q git epel-release
    yum install -y -q ansible MySQL-python python-psycopg2
}

function add_motd {
    # Add motd content
    cat >> "/etc/motd" << EOF

DBControl Node: An encrypted 1TB scratch volume is avabile at /mnt/scratch.
EOF
}

function setup_scratch_disk {
    mkfs -t ext4 /dev/xvdb
    mkdir /mnt/scratch
    mount /dev/xvdb /mnt/scratch

    # Add iam-synced-users group if it does not yet exist
    /usr/bin/getent group iam-synced-users >/dev/null 2>&1 || /usr/sbin/groupadd iam-synced-users
    chown root:iam-synced-users /mnt/scratch/
    chmod -R 770 /mnt/scratch/
    chmod g+s /mnt/scratch/
    setfacl -d -m g::rwx /mnt/scratch/
}

# Add Configuration
add_motd
setup_scratch_disk
# Install Dependencies
install_mysql
install_mongodb
install_percona_toolkit
install_python_modules
install_other_dependencies
