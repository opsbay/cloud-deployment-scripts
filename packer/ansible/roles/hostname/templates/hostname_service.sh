#!/bin/sh
#
# hostnameagentlinker   Hostname agent service for Centos 6.
#
# chkconfig: - 11 60
# description: Hostname agent service for hobsons

# Skeleton service from --> https://blog.hazrulnizam.com/create-init-script-centos-6/

# Source function library.
. /etc/init.d/functions

RETVAL=0
PROGRAM="hostnameagentlinker"
# This does not requires a Lock file, as it's oneshot

# Import functions
. /opt/hostname_agent/common.sh

start() {
        echo "Starting $PROGRAM: "
        update_hostname
        RETVAL=$?
        return $RETVAL
}

stop() {
        echo "Nothing to stop!"
        return 0
}

status() {
        echo "Checking $PROGRAM status: "
        hostname
        RETVAL=$?
        return $RETVAL
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        stop
        start
        ;;
    reload)
        stop
        start
        ;;
    *)
        echo "Usage: service $PROGRAM {start|stop|status|reload|restart}"
        exit 1
        ;;
esac
exit $?
