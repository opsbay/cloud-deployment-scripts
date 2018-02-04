#!/usr/bin/env bash
#
# configure-tmp-dirs-centos.sh
#
# Install and/or configure tools to periodically clean out /tmp/docs /tmp/deliver /tmp/upload-api directory of old files.
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

function configure-tmp-dirs-centos::get-systemd-timer() {
    cat <<END_OF_FILE
[Unit]
Description=Daily Cleanup of Temporary Directories
Documentation=man:tmpfiles.d(5) man:systemd-tmpfiles(8)

[Timer]
OnBootSec=15min
OnUnitActiveSec=2h
END_OF_FILE
}


VERSION=$(get_os_major_version)
DISTRIBUTION=$(get_os_distribution)
TMPWATCH_RPM="tmpwatch.x86_64"

if [[ "${DISTRIBUTION}" = "CentOS" ]]; then
    case "${VERSION}" in
        6)
            if rpm -q "${TMPWATCH_RPM}"; then
                echo "${TMPWATCH_RPM} already installed"
            else
                yum install -q -y "${TMPWATCH_RPM}"
            fi
            echo "0 * * * * root /usr/bin/tmpwatch 2h /tmp/edocs/" > /etc/cron.d/tmpwatch_docs
            echo "0 * * * * root /usr/bin/tmpwatch 2h /tmp/edocs/" > /etc/cron.d/tmpwatch_deliver
            echo "0 * * * * root /usr/bin/tmpwatch 2h /tmp/edocs/" > /etc/cron.d/tmpwatch_upload-api
            ;;
        7)
            echo "d /tmp/docs 770 nginx nginx 1d" > /etc/tmpfiles.d/tmp-docs.conf
            echo "d /tmp/deliver 770 nginx nginx 1d" > /etc/tmpfiles.d/tmp-deliver.conf
            echo "d /tmp/upload-api 770 nginx nginx 1d" > /etc/tmpfiles.d/tmp-upload-api.conf
            configure-tmp-dirs-centos::get-systemd-timer > /usr/lib/systemd/system/systemd-tmpfiles-clean.timer
            systemctl daemon-reload
            ;;
        *)
            echo "ERROR: Unknown OS version ${DISTRIBUTION} ${VERSION}"
            exit 1
            ;;
    esac
fi
