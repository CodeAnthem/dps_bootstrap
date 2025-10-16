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
readonly REPO_NAME="dps_bootstrap"
readonly REPO_PATH="/tmp/${REPO_NAME}"
readonly REPO_PATH_BOOTSTRAPPER="${REPO_PATH}/bootstrap/"
readonly REPO_TARGET_SCRIPT="main.sh"


# =============================================================================
# SETUP REPOSITORY
# =============================================================================
cloneRepo() {
    if git clone --quiet $REPO_URL $REPO_PATH 2>/dev/null; then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Successfully cloned repository" >&2;
    else
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "❌" "start.sh | Failed to clone repository" >&2;
        echo " -> Please check your internet connection and try again"
        exit 1
    fi
}
pullRepo() {
    if git -C $REPO_PATH pull --quiet 2>/dev/null; then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Successfully pulled repository" >&2;
    else
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "❌" "start.sh | Failed to pull repository" >&2;
        echo " To avoid unintentional manipulation of the repository, please confirm the following actions by pressing enter:"
        echo "   - Fetch origin"
        echo "   - Reset to latest commit"
        echo "   - Clean repository (remove all untracked files)"
        read -rn1 -p " Press enter to continue or anything else to exit: " REPLY
        if [[ $REPLY != "" ]]; then echo " -> Aborted!" >&2; exit 1; fi
        if git -C $REPO_PATH fetch origin --quiet \
        && git -C $REPO_PATH reset --hard origin/"$(git -C $REPO_PATH rev-parse --abbrev-ref HEAD)" --quiet \
        && git -C $REPO_PATH clean -fdx --quiet
        then
            printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Successfully reset repository" >&2;
        else
            printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "❌" "start.sh | Failed to reset repository" >&2;
            exit 1
        fi
    fi
}


# =============================================================================
# MAIN
# =============================================================================
# Check if repo already exists
if [[ -d "$REPO_PATH" ]]; then pullRepo; else cloneRepo; fi

# Start bootstrap script
# cd $REPO_PATH_BOOTSTRAPPER
# chmod +x $REPO_TARGET_SCRIPT
printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | starting ${REPO_TARGET_SCRIPT} script" >&2;
exec ${REPO_PATH_BOOTSTRAPPER}/${REPO_TARGET_SCRIPT} "$@"
