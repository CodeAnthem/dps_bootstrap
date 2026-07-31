#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake host discovery (nixosConfigurations)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-07-31
# Description:   List nixosConfigurations attrs from a flake root for host picker
# ==================================================================================================

# Description: List nixosConfigurations attribute names from a flake checkout.
# Arguments:
# - flake_root: <String> Path to flake directory
# Returns:
# - <String> host names one per line (stdout); non-zero on failure
nds_flake_list_hosts() {
    local flake_root="$1"
    local out

    [[ -d "$flake_root" && -f "${flake_root}/flake.nix" ]] || return 1

    if ! out=$(nix eval --json --impure \
        --extra-experimental-features 'nix-command flakes' \
        "${flake_root}#nixosConfigurations" \
        --apply 'c: builtins.attrNames c' 2>/dev/null); then
        return 1
    fi

    # JSON array of strings → lines
    printf '%s\n' "$out" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk 'NF'
}

# Description: Interactive host picker; sets FLAKE_HOST / NETWORK_HOSTNAME.
# Arguments:
# - flake_root: <String> Flake path
# Returns:
# - 0 on selection, NDS_ACTION_BACK on back, 1 on failure
nds_flake_pick_host() {
    local flake_root="$1"
    local -a hosts=()
    local options labels i host default rc

    mapfile -t hosts < <(nds_flake_list_hosts "$flake_root")
    if [[ ${#hosts[@]} -eq 0 ]]; then
        warn "Could not list nixosConfigurations — enter host name manually."
        nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "" true
        host="$(nds_cfg_get FLAKE_HOST)"
        [[ -n "$host" ]] || return 1
        nds_cfg_set NETWORK_HOSTNAME "$host"
        return 0
    fi

    options="$(printf '%s|' "${hosts[@]}")"
    options="${options%|}"
    labels=""
    for host in "${hosts[@]}"; do
        labels+="${host}=${host}|"
    done
    labels="${labels%|}"
    default="${hosts[0]}"

    nds_cfg_section_title "Select nixosConfigurations host"
    nds_cfg_ask_numbered_choice FLAKE_HOST "$options" "$labels" "$default" true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    host="$(nds_cfg_get FLAKE_HOST)"
    nds_cfg_set NETWORK_HOSTNAME "$host"
    return 0
}
