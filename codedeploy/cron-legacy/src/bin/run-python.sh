#!/usr/bin/env bash

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
#shellcheck disable=SC2034
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CENTOS_MAJOR_VERSION=$( sed 's/^.* \([0-9]\)\..*$/\1/' /etc/redhat-release )

if [[ $# -gt 0 ]]; then
    if [[ "$CENTOS_MAJOR_VERSION" == "6" ]]; then
        scl enable python27 "source \"$DIR/venv/bin/activate\" ; $* "
    else
        # shellcheck disable=SC1090
        # shellcheck disable=SC2048
        ( source "$DIR/venv/bin/activate" ; $* )
    fi
else
    echo "ERROR: need a parameter pointing to the python script to be executed."
    exit 1
fi
