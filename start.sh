#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2025-11-12
# Description:   One-liner to start DPS Bootstrap script by downloading repo to /tmp
# Feature:       Clone or reset repository, check for untracked files, execute target script
# ==================================================================================================

set -euo pipefail

# ----------------------------------------------------------------------------------
# SCRIPT METADATA
# ----------------------------------------------------------------------------------
readonly REPO_URL="https://github.com/codeAnthem/dps_bootstrap.git"
readonly REPO_NAME="dps_bootstrap"
readonly REPO_PATH="/tmp/${REPO_NAME}"
readonly REPO_PATH_BOOTSTRAPPER="${REPO_PATH}/bootstrap/"
readonly REPO_TARGET_SCRIPT="main.sh"
readonly DEFAULT_BRANCHES=("main" "master")

# ----------------------------------------------------------------------------------
# GLOBAL VARIABLES
# ----------------------------------------------------------------------------------
NO_EXEC=0


# ----------------------------------------------------------------------------------
# FORMAT HELPER
# ----------------------------------------------------------------------------------
console() { echo "${1:-}" >&2; }
log() { printf " %(%Y-%m-%d %H:%M:%S)T Quickstart | %s\n" -1 "$1" >&2; }

# ----------------------------------------------------------------------------------
# ARGUMENT PARSING
# ----------------------------------------------------------------------------------
TARGET_SCRIPT_ARGS=()
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dev)
                TARGET_BRANCH="dev"
                shift
                ;;
            --branch:*)
                TARGET_BRANCH="${1#--branch:}"
                shift
                ;;
            -n|--no-exec)
                NO_EXEC=1
                shift
                ;;
            *)
                # Store unknown arguments to pass to target script
                TARGET_SCRIPT_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# ----------------------------------------------------------------------------------
# BRANCH VALIDATION
# ----------------------------------------------------------------------------------
TARGET_BRANCH=""  # Empty by default, will be set by args or defaults
check_remote_branch() {
    local branch="$1"
    if git ls-remote --heads --exit-code "$REPO_URL" "refs/heads/$branch" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

branch_error() {
    local branch="$1"
    log "ERROR: Branch '$branch' does not exist in repository"
    console " -> Repository: $REPO_URL"
    console " -> Please specify a valid branch using --branch:name or --dev"
    exit 1
}

select_branch() {
    # If TARGET_BRANCH is set (via arguments), validate it
    if [[ -n "$TARGET_BRANCH" ]]; then
        if check_remote_branch "$TARGET_BRANCH"; then
            log "Using branch: $TARGET_BRANCH"
            return 0
        else
            branch_error "$TARGET_BRANCH"
        fi
    fi

    # No branch specified, try defaults
    for branch in "${DEFAULT_BRANCHES[@]}"; do
        if check_remote_branch "$branch"; then
            TARGET_BRANCH="$branch"
            log "Using default branch: $TARGET_BRANCH"
            return 0
        fi
    done

    # None of the default branches exist
    log "WARNING: None of the default branches exist"
    console " -> Tried: ${DEFAULT_BRANCHES[*]}"
    console " -> Repository: $REPO_URL"
    exit 1
}

# ----------------------------------------------------------------------------------
# SETUP REPOSITORY
# ----------------------------------------------------------------------------------
cloneRepo() {
    if git clone --quiet --branch "$TARGET_BRANCH" "$REPO_URL" "$REPO_PATH" 2>/dev/null; then
        log "Successfully cloned repository"
    else
        log "Failed to clone repository"
        console " -> Please check your internet connection and try again"
        exit 1
    fi
}

resetRepo() {
    # Check if we need to switch branches
    local current_branch
    current_branch=$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD)
    
    if [[ "$current_branch" != "$TARGET_BRANCH" ]]; then
        log "Switching from $current_branch to $TARGET_BRANCH"
        if ! git -C "$REPO_PATH" fetch origin --quiet; then
            log "Failed to fetch repository"
            exit 1
        fi
        if ! git -C "$REPO_PATH" checkout "$TARGET_BRANCH" --quiet 2>/dev/null; then
            log "Failed to checkout branch $TARGET_BRANCH"
            exit 1
        fi
    fi
    
    # We use fetch and reset instead of pull to avoid any potential conflicts
    if git -C "$REPO_PATH" fetch origin --quiet \
    && git -C "$REPO_PATH" reset --hard origin/"$TARGET_BRANCH" --quiet
    then
        log "Successfully reset repository"
    else
        log "Failed to reset repository"
        exit 1
    fi
}

# ----------------------------------------------------------------------------------
# SECURITY CHECKS
# ----------------------------------------------------------------------------------
checkUntrackedFiles() {
    local untracked
    untracked=$(git -C "$REPO_PATH" ls-files --others --exclude-standard)
    if [[ -n "$untracked" ]]; then
        log "Untracked files detected (potential security risk)"
        # List all untracked files:
        for f in $(git -C "$REPO_PATH" ls-files --others --exclude-standard); do
            console " - (untracked) ${REPO_PATH}/${f}"
        done

        # Prompt user to delete untracked files
        read -rp " Delete untracked files to ensure repo purity? [Y/N]: " answer < /dev/tty
        case "${answer^^}" in
            Y)
                git -C "$REPO_PATH" clean -fdx --quiet
                log "Untracked files removed"
                ;;
            *)
                log "Proceeding with untracked files present"
                ;;
        esac
    fi
}

# ----------------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------------
# Parse arguments
parse_arguments "$@"

# Select and validate branch
select_branch

# Clone or reset repository
if [[ -d "$REPO_PATH" ]]; then resetRepo; else cloneRepo; fi

# Check for untracked files
checkUntrackedFiles

# If NO_EXEC is set, exit here
if [[ "$NO_EXEC" -eq 1 ]]; then
    log "No execution requested, exiting"
    exit 0
fi

# Execute target script with remaining arguments
log "Starting ${REPO_TARGET_SCRIPT} script"
exec bash -euo pipefail "${REPO_PATH_BOOTSTRAPPER}/${REPO_TARGET_SCRIPT}" "${TARGET_SCRIPT_ARGS[@]}"
