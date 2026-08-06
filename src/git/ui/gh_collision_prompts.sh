#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git UI: GitHub key title collision prompt
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================

# Description: Ask overwrite|alternate|cancel for a GH title collision.
# Sets NDS_GH_KEY_TITLE_COLLISION and NDS_GIT_SSH_KEY_TITLE_COLLISION.
# Arguments:
# - prompt: <String> User-facing message
nds_git_ui_ask_gh_title_collision() {
    local prompt="${1:?prompt}"
    local choice

    choice="${NDS_GH_KEY_TITLE_COLLISION:-${NDS_GIT_SSH_KEY_TITLE_COLLISION:-}}"
    if [[ -n "$choice" ]]; then
        return 0
    fi
    if declare -f nds_cfg_ask_numbered_choice &>/dev/null; then
        nds_cfg_set GIT_SSH_KEY_TITLE_COLLISION ""
        nds_ui_b ""
        nds_ui_b "$prompt"
        nds_ui_b ""
        nds_cfg_ask_numbered_choice GIT_SSH_KEY_TITLE_COLLISION \
            "overwrite|alternate|cancel" \
            "overwrite=Remove the old key and register this one|alternate=Use an alternate title|cancel=Cancel — choose a different approach"
        choice="$(nds_cfg_get GIT_SSH_KEY_TITLE_COLLISION)"
    else
        return 1
    fi
    case "$choice" in
        overwrite|alternate|cancel)
            NDS_GH_KEY_TITLE_COLLISION="$choice"
            NDS_GIT_SSH_KEY_TITLE_COLLISION="$choice"
            export NDS_GH_KEY_TITLE_COLLISION NDS_GIT_SSH_KEY_TITLE_COLLISION
            nds_cfg_set GIT_SSH_KEY_TITLE_COLLISION "$choice"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Compat private name used by older orch callers
_nds_git_ask_gh_title_collision() {
    nds_git_ui_ask_gh_title_collision "$@"
}
