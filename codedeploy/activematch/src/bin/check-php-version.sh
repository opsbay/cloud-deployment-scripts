#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Enhance debugging by expanding and showing shell commands
set -x

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#shellcheck disable=SC1090
source "$DIR/common.sh"

build_php_version=$(cat "${APP_CONFIG_DIR}/phpversion.txt")

if [[ "${INSTALLED_PHP_VERSION}" != "$build_php_version" ]]; then
    echo "Unsupported PHP version"
    echo "The version used is ${INSTALLED_PHP_VERSION} although only PHP $build_php_version is supported."
    echo "Terminating."
    exit 1
fi
