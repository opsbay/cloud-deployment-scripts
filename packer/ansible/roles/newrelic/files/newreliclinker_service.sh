#!/bin/sh
#
# newreliclinker   Newrelic linker service for Centos 6.
#
# chkconfig: - 79 20
# description: Newrelic linker service for hobsons

# Skeleton service from --> https://blog.hazrulnizam.com/create-init-script-centos-6/

# Source function library.
#shellcheck disable=SC1091
. /etc/init.d/functions

RETVAL=0
PROGRAM="newreliclinker"
# This does not requires a Lock file, as it's oneshot

# Import functions
#shellcheck disable=SC1091
. /opt/newrelic/common.sh

start() {
        echo "Starting $PROGRAM: "
        configure_newrelic
        RETVAL=$?
        if [ $RETVAL -ne 0 ] ; then
            echo "Key not set"
        else
            echo "Key set"
        fi
        return $RETVAL
}

stop() {
        echo "Stopping $PROGRAM: [ Nothing to stop! ]"
        return 0
}

status() {
        echo "Checking $PROGRAM: [ Nothing to check! ]"
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
