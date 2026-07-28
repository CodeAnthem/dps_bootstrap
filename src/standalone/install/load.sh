#!/usr/bin/env bash
# ==================================================================================================
# NDS - Standalone install helpers loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   Load argument-only install modules (no NDS config)
# ==================================================================================================

nds_standalone_install_load() {
    [[ "${NDS_STANDALONE_INSTALL_LOADED:-false}" == "true" ]] && return 0
    local base="${SCRIPT_DIR}/standalone/install"

    nds_import_file "${base}/disk-part.sh" || return 1
    nds_import_file "${base}/urandom.sh" || return 1
    nds_import_file "${base}/access-secrets.sh" || return 1
    nds_import_file "${base}/luks.sh" || return 1
    nds_import_file "${base}/partition.sh" || return 1
    NDS_STANDALONE_INSTALL_LOADED=true
    return 0
}
