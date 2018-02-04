#!/usr/bin/env bash
#
# deploy-all.sh
#
# Deploys the placeholder app to all testapp environments

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Credit to Stack Overflow questioner Jiarro and answerer Dave Dopson
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
# http://stackoverflow.com/a/246128/424301
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$DIR/.."
for ee in 56 53 ubuntu; do
    for group in qa staging; do
        app="tf-testapp-$ee"
        make all deploy DEPLOYMENT_APP="$app" DEPLOYMENT_GROUP="$group" 
    done
done
