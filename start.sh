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
    if git clone --quiet "$REPO_URL" "$REPO_PATH" 2>/dev/null; then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Successfully cloned repository" >&2
    else
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "❌" "start.sh | Failed to clone repository" >&2
        echo " -> Please check your internet connection and try again"
        exit 1
    fi
}

pullRepo() {
    if git -C "$REPO_PATH" pull --quiet 2>/dev/null; then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Successfully pulled repository" >&2
    else
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "⚠️" "start.sh | Pull failed, attempting hard reset" >&2
        git -C "$REPO_PATH" fetch origin --quiet
        git -C "$REPO_PATH" reset --hard origin/"$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD)" --quiet
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Repository reset to remote" >&2
    fi
}

# =============================================================================
# SECURITY CHECKS
# =============================================================================
checkUntrackedFiles() {
    local untracked
    untracked=$(git -C "$REPO_PATH" ls-files --others --exclude-standard)
    if [[ -n "$untracked" ]]; then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "⚠️" "start.sh | Untracked files detected (potential security risk)" >&2
        echo "$untracked" >&2
        read -rp " Delete untracked files to ensure repo purity? [Y/N]: " answer
        case "${answer^^}" in
            Y)
                git -C "$REPO_PATH" clean -fdx --quiet
                printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Untracked files removed" >&2
                ;;
            *)
                printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "⚠️" "start.sh | Proceeding with untracked files present" >&2
                ;;
        esac
    fi
}

# =============================================================================
# MAIN
# =============================================================================
if [[ -d "$REPO_PATH" ]]; then
    pullRepo
else
    cloneRepo
fi

checkUntrackedFiles

printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | starting ${REPO_TARGET_SCRIPT} script" >&2
exec "${REPO_PATH_BOOTSTRAPPER}/${REPO_TARGET_SCRIPT}" "$@"
