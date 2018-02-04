#!/bin/sh
#
# /etc/init.d/splunk_linker
# init script for Splunk.
#
# chkconfig: 2345 85 60
#
RETVAL=0
PROGRAM="splunk_linker"

. /etc/init.d/functions

# Import functions
. /opt/splunkforwarder/common.sh

splunk_start() {
    echo "Starting $PROGRAM: "

    set_splunk_config

    RETVAL=$?
    return $RETVAL
}

splunk_stop() {
    echo "Nothing to stop!"
    return 0
}

splunk_status() {
    echo "Checking $PROGRAM status: "
    "/opt/splunkforwarder/bin/splunk" status
    RETVAL=$?
    return $RETVAL
}

case "$1" in
    start)
        splunk_start
    ;;

    stop)
        splunk_stop
    ;;

    restart)
        splunk_stop
        splunk_start
    ;;

    status)
        splunk_status
    ;;

    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
    ;;
esac

exit $RETVAL