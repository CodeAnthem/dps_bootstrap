#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth flow logic (framework)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-08-05
# Description:   NDS-aware auth gates without interactive UI
# ==================================================================================================

# Description: Try import path, session keys, and discovered ~/.ssh keys.
# Arguments:
# - url: <String> Git URL to probe
# Returns:
# - <Bool> 0 when access works with an existing key
_git_auth_try_existing_access() {
    local url="$1"
    local found

    nds_git_auth_try_import_path && nds_git_keys_register "$(nds_git_session_key_path)" 2>/dev/null || true
    if nds_git_probe_access "$url"; then
        nds_git_auth_set_mode imported
        return 0
    fi

    nds_git_auth_try_session_key && nds_git_keys_register "$(nds_git_session_key_path)" 2>/dev/null || true
    nds_git_keys_load_all || true
    if nds_git_probe_access "$url"; then
        return 0
    fi

    if found="$(nds_git_discover_try_candidates "$url")"; then
        nds_git_auth_set_mode imported
        debug "Git access via discovered key: ${found}"
        return 0
    fi
    return 1
}
