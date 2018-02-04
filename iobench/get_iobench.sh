#!/usr/bin/env bash

# git
if rpm -qa | grep -q git > /dev/null; then
	echo === git already installed
else
	echo === installing git
    sudo yum install -y git
fi

# assuming ssh with -A so git credentials are not an issue
git clone git@github.com:naviance/cloud-deployment-scripts.git ~/cloud-deployment-scripts

cd ~/cloud-deployment-scripts
git checkout NAWS-429
cd iobench

ls -l

# the end, my only friend, the end.
