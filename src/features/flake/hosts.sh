#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake host discovery (nixosConfigurations)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-03
# Description:   List nixosConfigurations attrs from a flake root for host picker
# ==================================================================================================

# Description: List nixosConfigurations attribute names from a flake checkout.
# Arguments:
# - flake_root: <String> Path to flake directory
# Returns:
# - <String> host names one per line (stdout); non-zero on failure
nds_flake_list_hosts() {
    local flake_root="$1"
    local out errfile rc=0
    local flake_ref

    [[ -d "$flake_root" && -f "${flake_root}/flake.nix" ]] || return 1
    flake_ref="path:$(readlink -f "$flake_root" 2>/dev/null || printf '%s' "$flake_root")"
    errfile="${NDS_RUNTIME_DIR:-/tmp/nds}/flake_hosts.err"
    mkdir -p "$(dirname "$errfile")"

    # Prefer lazy attrNames via getFlake (avoids forcing full host eval when possible).
    if out=$(nix eval --impure --extra-experimental-features 'nix-command flakes' \
        --expr "builtins.concatStringsSep \"\\n\" (builtins.attrNames (builtins.getFlake \"${flake_ref}\").nixosConfigurations)" \
        2>"$errfile"); then
        printf '%s\n' "$out" | awk 'NF'
        return 0
    fi

    # Fallback: flake#nixosConfigurations apply
    if out=$(nix eval --json --impure \
        --extra-experimental-features 'nix-command flakes' \
        "${flake_ref}#nixosConfigurations" \
        --apply 'c: builtins.attrNames c' 2>>"$errfile"); then
        printf '%s\n' "$out" | tr -d '[]"' | tr ',' '\n' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk 'NF'
        return 0
    fi

    debug "nixosConfigurations listing failed (see ${errfile})"
    return 1
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

    nds_ui_section_header "Select host"
    if declare -f nds_step_start &>/dev/null; then
        nds_step_start "Listing nixosConfigurations"
        mapfile -t hosts < <(nds_flake_list_hosts "$flake_root")
        if [[ ${#hosts[@]} -gt 0 ]]; then
            nds_step_complete "Listing nixosConfigurations"
        else
            nds_step_fail "Listing nixosConfigurations"
        fi
    else
        mapfile -t hosts < <(nds_flake_list_hosts "$flake_root")
    fi

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
