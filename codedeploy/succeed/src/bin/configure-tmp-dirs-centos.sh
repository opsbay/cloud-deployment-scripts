#!/usr/bin/env bash
#
# configure-tmp-dirs-centos.sh
#
# Install and/or configure tools to periodically clean out /tmp/edocs directory of old files.
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

function configure-tmp-dirs-centos::get-tmpfiles-script() {
    cat <<END_OF_FILE
#!/usr/bin/env bash
/usr/bin/systemd-tmpfiles --clean
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
            echo "0 * * * * root /usr/bin/tmpwatch 2h /tmp/edocs/" > /etc/cron.d/tmpwatch_edocs
            ;;
        7)
            # This satisfies both:
            # https://jira.hobsons.com/browse/NAWS-806
            # https://jira.hobsons.com/browse/NAWS-1353
            echo "d /tmp/edocs 770 nginx nginx 2h" > /etc/tmpfiles.d/tmp-edocs.conf
            chmod 0500 /etc/tmpfiles.d/tmp-edocs.conf
            configure-tmp-dirs-centos::get-tmpfiles-script > /etc/cron.hourly/tmpfiles_edocs
            chmod +x /etc/cron.hourly/tmpfiles_edocs
            printf '[Service]\nPrivateTmp=false\n' > /etc/systemd/system/php-fpm.service.d/privatetmp.conf
            systemctl daemon-reload
            systemd-tmpfiles --create
            label_selinux "/tmp/edocs"
            ;;
        *)
            echo "ERROR: Unknown OS version ${DISTRIBUTION} ${VERSION}"
            exit 1
            ;;
    esac
fi
