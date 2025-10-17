#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-10-16
# Description:   One-liner to start DPS Bootstrap script by downloading repo to /tmp
# Feature:       Clone or reset repository, check for untracked files, execute target script
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

resetRepo() {
    # We use fetch and reset instead of pull to avoid any potential conflicts
    if git -C "$REPO_PATH" fetch origin --quiet \
    && git -C "$REPO_PATH" reset --hard origin/"$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD)" --quiet
    then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Successfully reset repository" >&2;
    else
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "❌" "start.sh | Failed to reset repository" >&2;
        exit 1
    fi
}

# =============================================================================
# SECURITY CHECKS
# =============================================================================
checkUntrackedFiles() {
    local untracked
    untracked=$(git -C "$REPO_PATH" ls-files --others --exclude-standard)
    if [[ -n "$untracked" ]]; then
        printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "⚠️ " "start.sh | Untracked files detected (potential security risk)" >&2
        # List all untracked files:
        for f in $(git -C "$REPO_PATH" ls-files --others --exclude-standard); do
            echo " - (untracked) ${REPO_PATH}/${f}" >&2
        done

        # Prompt user to delete untracked files
        read -rp " Delete untracked files to ensure repo purity? [Y/N]: " answer < /dev/tty
        case "${answer^^}" in
            Y)
                git -C "$REPO_PATH" clean -fdx --quiet
                printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | Untracked files removed" >&2
                ;;
            *)
                printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "⚠️ " "start.sh | Proceeding with untracked files present" >&2
                ;;
        esac
    fi
}

# =============================================================================
# MAIN
# =============================================================================
# Clone or reset repository
if [[ -d "$REPO_PATH" ]]; then resetRepo; else cloneRepo; fi

# Check for untracked files
checkUntrackedFiles

# Execute target script
printf " %(%Y-%m-%d %H:%M:%S)T %s %s\n" -1 "✅" "start.sh | starting ${REPO_TARGET_SCRIPT} script" >&2
exec bash "${REPO_PATH_BOOTSTRAPPER}/${REPO_TARGET_SCRIPT}" "$@"
