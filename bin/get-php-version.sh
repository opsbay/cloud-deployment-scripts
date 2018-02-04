#!/usr/bin/env bash
set -euo pipefail

PHP_VERSION=${1:-}
case $PHP_VERSION in
    "53"|"5.3")  echo 53; ;;
    "56"|"5.6") echo 56; ;;
    *) echo invalid; ;;
esac
