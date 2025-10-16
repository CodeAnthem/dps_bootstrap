#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-10-16
# Description:   One-liner to start DPS Bootstrap script by downloading repo to /tmp
# Feature:       Simple Git repo downloader and executor
# ==================================================================================================

set -euo pipefail

# =============================================================================
# SCRIPT METADATA
# =============================================================================
readonly REPO_URL="https://github.com/codeAnthem/dps_bootstrap.git"
readonly SCRIPT_VERSION="1.0.0"
readonly REPO_NAME="dps_bootstrap"
readonly REPO_PATH="/tmp/${REPO_NAME}"
readonly REPO_PATH_BOOTSTRAPPER="${REPO_PATH}/bootstrap/"
readonly REPO_TARGET_SCRIPT="${REPO_PATH_BOOTSTRAPPER}/main.sh"

# =============================================================================
# SETUP REPOSITORY
# =============================================================================
cloneRepo() {
    if git clone --quiet $REPO_URL $REPO_PATH 2>/dev/null; then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "Successfully cloned repository" >&2;
    else
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "❌" "Failed to clone repository" >&2;
        echo "Please check your internet connection and try again"
        exit 1
    fi
}
pullRepo() {
    if git pull --quiet $REPO_URL $REPO_PATH 2>/dev/null; then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "Successfully pulled repository" >&2;
    else
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "❌" "Failed to pull repository" >&2;
        echo "Please check your internet connection and try again"
        exit 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================
echo "=== DPS Bootstrap - start.sh ($SCRIPT_VERSION) ==="

# Check if repo already exists
if [[ -d "$REPO_PATH" ]]; then pullRepo; else cloneRepo; fi

# Make script executable
chmod +x $REPO_PATH_BOOTSTRAPPER/*.sh

# Start bootstrap script
cd $REPO_PATH_BOOTSTRAPPER
exec $REPO_TARGET_SCRIPT "$@"
