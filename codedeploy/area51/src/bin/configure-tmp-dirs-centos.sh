#!/usr/bin/env bash
#
# configure-tmp-dirs-centos.sh
#
# Install and/or configure tools to periodically clean out  directory of old files.
#
# For CentOS 6, it uses tmpfiles.  For CentOS 7, it uses tmpwatch.

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

VERSION=$(get_os_major_version)
DISTRIBUTION=$(get_os_distribution)

if [[ "${DISTRIBUTION}" = "CentOS" ]]; then
    case "${VERSION}" in
        6)
            ;;
        7)
            echo "d ${CACHE_DIR} 755 nginx nginx 1d" > /etc/tmpfiles.d/tmp_html_purifier.conf
            systemd-tmpfiles --create
            label_selinux "${CACHE_DIR}" httpd_sys_content_t
            ;;
        *)
            echo "ERROR: Unknown OS version ${DISTRIBUTION} ${VERSION}"
            exit 1
            ;;
    esac
fi
