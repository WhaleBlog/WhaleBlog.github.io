#!/bin/bash
#
# This script deploys the application to a remote server using SSH and rsync.
# Usage: ./deploy.sh "commit message"

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}   $1"; }
error()   { echo -e "${RED}[ERROR]${NC}  $1" >&2; exit 1; }

# Step 1: Build Hugo site
info "Building Hugo site with minify..."
hugo --minify
if [ $? -ne 0 ]; then
    error "Hugo build failed. Deployment aborted."
fi
success "Hugo build completed successfully."

# Step 2: Handle commit message
export msg="$1"
export flag=""

if [ -z "$msg" ]; then
    warn "No commit message provided. Using default: 'Empty commit'"
    export flag="--allow-empty -m"
    export msg="Empty commit"
else
    export flag="-m"
fi

# Step 3: Git operations
info "Staging all changes..."
git add .

info "Committing changes with message: '$msg'"
git commit $flag "$msg"
if [ $? -ne 0 ]; then
    error "Git commit failed. Deployment aborted."
fi

info "Pushing to remote repository..."
git push origin master
if [ $? -ne 0 ]; then
    error "Git push failed. Deployment aborted."
fi

success "Deployment completed successfully!"