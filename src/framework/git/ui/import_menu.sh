#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard import menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-03
# Description:   Path-based key import (cwd/.ssh auto-scan runs before the wizard)
# ==================================================================================================

# Description: Import a private key from an explicit path (or NDS_GIT_IMPORT_KEY_PATH).
# Auto-discovery of cwd / ~/.ssh happens in _git_auth_try_existing_access before menus.
# Arguments:
# - urls: <String...> URLs to probe after import (optional; for messaging)
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_import_path() {
    local -a urls=("$@")
    local src

    if [[ -n "${NDS_GIT_IMPORT_KEY_PATH:-}" && -f "${NDS_GIT_IMPORT_KEY_PATH}" ]]; then
        src="${NDS_GIT_IMPORT_KEY_PATH}"
    elif [[ -n "${NDS_DEPLOY_KEY_PATH:-}" && -f "${NDS_DEPLOY_KEY_PATH}" ]]; then
        src="${NDS_DEPLOY_KEY_PATH}"
    else
        nds_cfg_ask_path GIT_IMPORT_KEY_PATH "Private SSH key path" "" true || return 1
        src="$(nds_cfg_get GIT_IMPORT_KEY_PATH)"
    fi

    [[ -f "$src" ]] || {
        error "Private key not found: ${src}"
        return 1
    }

    nds_git_keys_register "$src" || return 1
    nds_git_auth_set_mode imported

    if [[ ${#urls[@]} -gt 0 ]]; then
        if nds_git_discover_probe_urls "$src" "${urls[@]}"; then
            success "SSH key works: ${src}"
            return 0
        fi
        warn "Key loaded but probe failed for one or more URLs — continue after fixing access."
    fi
    success "SSH key loaded from ${src}"
    return 0
}

# Compatibility: older callers expected auto-scan + path fallback.
nds_git_wizard_menu_import() {
    local -a urls=("$@")
    local found

    info "Looking for existing SSH private keys in this directory and /root/.ssh ..."
    if found="$(nds_git_discover_try_candidates "${urls[@]}")"; then
        nds_git_auth_set_mode imported
        success "SSH key works: ${found}"
        return 0
    fi

    warn "No working key found automatically."
    nds_git_wizard_menu_import_path "${urls[@]}"
}
