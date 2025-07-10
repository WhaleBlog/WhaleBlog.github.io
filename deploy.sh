#!/bin/bash

# This script deploys the application to a remote server using SSH and rsync.
# Usage: ./deploy.sh "commit message"

export msg="$1"
export flag="-m"

if [ -z "$msg" ]; then
    export flag="--allow-empty"
fi

git add .
git commit $flag "$msg"
git push origin master