#!/bin/bash

set -uo pipefail

case "$TRAVIS_OS_NAME" in
  linux)
    docker info
    docker version

    echo "==> Prefetching .rpm and .tar.gz to '$PWD/files'..."
    docker build  -f test/Dockerfile-prefetch-rpm      -t java_prefetch_rpm .
    docker run    -v $(pwd):/data  java_prefetch_rpm
    docker build  -f test/Dockerfile-prefetch-tarball  -t java_prefetch_tarball .
    docker run    -v $(pwd):/data  java_prefetch_tarball
    sed -i -e 's/^\(java_download_from_oracle:\).*$/\1 false/'  defaults/main.yml

  ;;
  osx)
    echo "==> Installing Ansible using pip on Mac OS X"
    sudo pip install ansible
  ;;
  *)
    echo "Unknown value of TRAVIS_OS_NAME: '$TRAVIS_OS_NAME'" >&2
    exit 1
esac
