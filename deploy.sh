#!/bin/bash

# This script deploys the application to a remote server using SSH and rsync.
# Usage: ./deploy.sh "commit message"

export msg="$1"
export flag="-m"

if [ -z "$msg" ]; then
    export flag="--allow-empty -m"
    export msg="Empty commit"
    echo "No commit message provided. Using default: '$msg'"
fi

git add .
git commit $flag "$msg"
git push origin master