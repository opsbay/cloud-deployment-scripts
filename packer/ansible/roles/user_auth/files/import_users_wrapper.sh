#!/usr/bin/env bash

# Sleep for a random amount of time between 0 and 3600 seconds
sleep $(( RANDOM % 3600 ))s

/opt/import_users.sh
