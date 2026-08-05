#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake host scaffold prompts
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Interactive existing/new host scaffold; writes AA via nds_aa_ask_*
# ==================================================================================================

# Description: Two-step host selection against a checked-out flake.
# Arguments:
# - flake_root: <String> Path to the checked-out flake
# - system:     <String|optional> Nix system (default: x86_64-linux)
nds_flake_scaffold_interactive() {
    local flake_root="$1"
    local system="${2:-x86_64-linux}"
    local roles hosts_dir existing default_role
    local prev_aa="${NDS_CFG_AA_NAME:-}"
    local -A _scaf_aa=()
    local owned=false

    roles="$(_flake_discover_roles "$flake_root")"
    if [[ -z "$roles" ]]; then
        return 1
    fi

    if [[ -z "$prev_aa" ]]; then
        nds_cfg_aa_from_store _scaf_aa
        nds_cfg_aa_bind _scaf_aa
        owned=true
    fi

    hosts_dir="${flake_root}/hosts/${system}"
    existing=""
    if [[ -d "$hosts_dir" ]]; then
        existing="$(find "$hosts_dir" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null \
            | sort | tr '\n' '|' | sed 's/|$//')"
    fi

    nds_cfg_section_title "Host selection"

    if [[ -n "$existing" ]]; then
        nds_aa_ask_choice SCAFFOLD_MODE "Host" "existing|new" \
            "existing=Use an existing host|new=Scaffold a new host" "existing"
    else
        nds_feat_cfg_set SCAFFOLD_MODE "new"
    fi

    if nds_feat_cfg_is SCAFFOLD_MODE existing; then
        local first_host
        first_host="${existing%%|*}"
        nds_aa_ask_choice FLAKE_HOST "Existing host" "$existing" "" "$first_host"
        nds_feat_cfg_set NETWORK_HOSTNAME "$(nds_feat_cfg_get FLAKE_HOST)"
        NDS_FLAKE_HOST="$(nds_feat_cfg_get FLAKE_HOST)"
        export NDS_FLAKE_HOST
        if [[ "$owned" == true ]]; then
            nds_cfg_aa_to_store _scaf_aa
            NDS_CFG_AA_NAME="$prev_aa"
        fi
        return 0
    fi

    default_role="${roles%%|*}"
    nds_aa_ask_choice SCAFFOLD_ROLE "Role" "$roles" "" "$default_role"
    nds_aa_ask_hostname FLAKE_HOST "New host name" "" true

    local host role
    host="$(nds_feat_cfg_get FLAKE_HOST)"
    role="$(nds_feat_cfg_get SCAFFOLD_ROLE)"
    nds_feat_cfg_set NETWORK_HOSTNAME "$host"
    export NDS_FLAKE_HOST="$host"

    _flake_scaffold_host_folder "$flake_root" "$host" "$role" "$system" || {
        if [[ "$owned" == true ]]; then
            nds_cfg_aa_to_store _scaf_aa
            NDS_CFG_AA_NAME="$prev_aa"
        fi
        return 1
    }

    export NDS_FLAKE_SOURCE="local"
    export NDS_FLAKE_LOCAL_PATH="$flake_root"
    nds_feat_cfg_set FLAKE_SOURCE "local"
    nds_feat_cfg_set FLAKE_LOCAL_PATH "$flake_root"

    log "New host '${host}' scaffolded — review and commit ${flake_root}/hosts/${system}/${host}"
    if [[ "$owned" == true ]]; then
        nds_cfg_aa_to_store _scaf_aa
        NDS_CFG_AA_NAME="$prev_aa"
    fi
    return 0
}
