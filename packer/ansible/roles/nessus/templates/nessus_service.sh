#!/bin/sh
#
# nessusagentlinker   Nessus agent service for Centos 6.
#
# chkconfig: - 90 60
# description: Nessus agent service for hobsons

# Skeleton service from --> https://blog.hazrulnizam.com/create-init-script-centos-6/

# Source function library.
. /etc/init.d/functions

RETVAL=0
PROGRAM="nessusagentlinker"
# This does not requires a Lock file, as it's oneshot

# Import functions
. /opt/nessus_agent/common.sh

start() {
        echo "Starting $PROGRAM: "
        connect_to_nessus
        RETVAL=$?
        return $RETVAL
}

stop() {
        echo "Nothing to stop!"
        return 0
}

status() {
        echo "Checking $PROGRAM status: "
        get_nessus_status
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
