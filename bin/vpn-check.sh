#!/usr/bin/env bash
#
# vpn-check.sh
#
# Verifies that you are conntected to the VPN. If not, it errors out with a message.
# See: https://jira.hobsons.com/browse/NAWS-230

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

declare -i conn_timeout
conn_timeout=30

declare target
target=${1:-https://composer.hobsonshighered.com/}

declare vpn_server
vpn_server=${2:-dca-fw-01.hobsons.com}

echo "$0: checking connectivity to $target..."
set +e
vpn_connection=$(curl --connect-timeout $conn_timeout -I -s -o /dev/null -w "%{http_code}" "$target")
set -e

if [[ "$vpn_connection" -ne 200 ]]; then
    echo "Double-check that you are on the Hobsons corporate network."
    echo "If you are not on site, you must connect to the VPN through this server: $vpn_server"
    echo "$0: ERROR: Connectivity check to $target failed"
    exit 1
else
    echo "$0: OK: Connectivity check to $target succeeded"
fi
