#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

rm -rf /opt/exampleapp/

mkdir -p /opt/exampleapp/
