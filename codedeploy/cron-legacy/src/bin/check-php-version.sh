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

php_version=$(php --version)
deploy_php_version=$(echo "$php_version" | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
build_php_version=$(cat "${APP_CONFIG_DIR}/phpversion.txt")

if [[ "$deploy_php_version" != "$build_php_version" ]]; then
    echo "Unsupported PHP version"
    echo "The version used is $php_version although only PHP $build_php_version is supported."
    echo "Terminating."
    exit 1
fi

#shellcheck disable=SC2089
include_config='include_path=".:/httpd/k12/wk12/includes:/httpd/k12/vendor/zendframework/zendframework1/library"'
#shellcheck disable=SC2153
if [[ "$PHP_VERSION" == "56" ]]; then
    if ! grep -Fxq "$include_config" /etc/php.ini ; then
        #shellcheck disable=SC2090
        sed -i 's|include_path=.*$|'$include_config'|' /etc/php.ini
    fi
fi
