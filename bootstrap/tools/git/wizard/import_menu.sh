#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard import menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Import flow — discover keys, prompt path, load session key.
# Arguments:
# - urls: <String...> URLs to probe after import
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_import() {
    local -a urls=("$@")
    local found src dest

    info "Looking for existing SSH private keys in this directory and /root/.ssh ..."
    if found="$(nds_git_discover_try_candidates "${urls[@]}")"; then
        success "SSH key works: ${found}"
        return 0
    fi

    warn "No working key found automatically."
    if [[ -n "${NDS_GIT_IMPORT_KEY_PATH:-}" && -f "${NDS_GIT_IMPORT_KEY_PATH}" ]]; then
        src="${NDS_GIT_IMPORT_KEY_PATH}"
    elif [[ -n "${NDS_DEPLOY_KEY_PATH:-}" && -f "${NDS_DEPLOY_KEY_PATH}" ]]; then
        src="${NDS_DEPLOY_KEY_PATH}"
    else
        nds_cfg_ask_path GIT_IMPORT_KEY_PATH "Private SSH key path" "" true || return 1
        src="$(nds_cfg_get GIT_IMPORT_KEY_PATH)"
    fi

    dest="$(nds_git_session_key_path)"
    nds_git_key_import "$src" "$dest" || return 1
    success "SSH key loaded from ${src}"
    return 0
}
