#!/usr/bin/env bash
# ==================================================================================================
# NDS - Standalone git helpers loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   Load argument-only git modules (no NDS config)
# ==================================================================================================

nds_standalone_git_load() {
    [[ "${NDS_STANDALONE_GIT_LOADED:-false}" == "true" ]] && return 0
    local base="${SCRIPT_DIR}/standalone/git"

    nds_import_file "${base}/url.sh" || return 1
    nds_import_file "${base}/hosts.sh" || return 1
    nds_import_file "${base}/probe.sh" || return 1
    nds_import_file "${base}/names.sh" || return 1
    nds_import_file "${base}/key.sh" || return 1
    NDS_STANDALONE_GIT_LOADED=true
    return 0
}
