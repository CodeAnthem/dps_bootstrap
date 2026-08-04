#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake host discovery (nixosConfigurations)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-03
# Description:   List nixosConfigurations attrs from a flake root for host picker
# ==================================================================================================

# Description: Resolve flake checkout path for host listing (gate probe, local, or cfg).
# Returns:
# - <String> Absolute flake root (stdout); non-zero when missing
nds_flake_resolve_root() {
    local root loc

    root="${1:-${NDS_FLAKE_GATE_ROOT:-}}"
    if [[ -z "$root" || ! -f "${root}/flake.nix" ]]; then
        root="$(nds_cfg_get FLAKE_LOCAL_PATH 2>/dev/null || true)"
    fi
    if [[ -z "$root" || ! -f "${root}/flake.nix" ]]; then
        root="${NDS_FLAKE_PROBE_REPO:-}"
    fi
    if [[ -z "$root" || ! -f "${root}/flake.nix" ]]; then
        loc="$(nds_cfg_get FLAKE_LOCATION 2>/dev/null || true)"
        [[ -n "$loc" && -f "${loc}/flake.nix" ]] && root="$loc"
    fi
    [[ -n "$root" && -f "${root}/flake.nix" ]] || return 1
    readlink -f "$root" 2>/dev/null || printf '%s\n' "$root"
}

# Description: List host names from flake host directory layout (filesystem fallback).
# Arguments:
# - flake_root: <String> Flake path
# Returns:
# - <String> directory names one per line
_flake_list_hosts_from_dir() {
    local flake_root="$1"
    local host_dir rel
    rel="$(nds_cfg_get FLAKE_HOST_DIR 2>/dev/null || true)"
    rel="${rel:-hosts/x86_64-linux}"
    host_dir="${flake_root}/${rel}"
    [[ -d "$host_dir" ]] || return 1
    find "$host_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

# Description: List nixosConfigurations attribute names from a flake checkout.
# Arguments:
# - flake_root: <String> Path to flake directory
# Returns:
# - <String> host names one per line (stdout); non-zero on failure
nds_flake_list_hosts() {
    local flake_root="$1"
    local out errfile flake_ref
    local -a from_dir=()

    [[ -d "$flake_root" && -f "${flake_root}/flake.nix" ]] || return 1
    flake_root="$(readlink -f "$flake_root" 2>/dev/null || printf '%s' "$flake_root")"
    flake_ref="path:${flake_root}"
    errfile="${NDS_RUNTIME_DIR:-/tmp/nds}/flake_hosts.err"
    mkdir -p "$(dirname "$errfile")"
    : >"$errfile"

    # 1) Eval from inside the flake (most reliable for locked inputs).
    if out=$(
        cd "$flake_root" || exit 1
        nix eval --impure --extra-experimental-features 'nix-command flakes' \
            --expr 'builtins.concatStringsSep "\n" (builtins.attrNames (builtins.getFlake (toString ./.)).nixosConfigurations)' \
            2>>"$errfile"
    ); then
        out="$(printf '%s\n' "$out" | awk 'NF')"
        if [[ -n "$out" ]]; then
            printf '%s\n' "$out"
            return 0
        fi
    fi

    # 2) path: flake URI + apply
    if out=$(nix eval --json --impure \
        --extra-experimental-features 'nix-command flakes' \
        "${flake_ref}#nixosConfigurations" \
        --apply 'c: builtins.attrNames c' 2>>"$errfile"); then
        out="$(printf '%s\n' "$out" | tr -d '[]"' | tr ',' '\n' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | awk 'NF')"
        if [[ -n "$out" ]]; then
            printf '%s\n' "$out"
            return 0
        fi
    fi

    # 3) nix flake show --json (lazy; needs jq when present)
    if command -v jq &>/dev/null; then
        if out=$(nix flake show --json --all-systems "$flake_ref" 2>>"$errfile" \
            | jq -r '.nixosConfigurations // {} | keys[]' 2>>"$errfile"); then
            out="$(printf '%s\n' "$out" | awk 'NF')"
            if [[ -n "$out" ]]; then
                printf '%s\n' "$out"
                return 0
            fi
        fi
    fi

    # 4) Filesystem fallback: FLAKE_HOST_DIR entries (common Thunderstorm layout)
    mapfile -t from_dir < <(_flake_list_hosts_from_dir "$flake_root")
    if [[ ${#from_dir[@]} -gt 0 ]]; then
        debug "nixosConfigurations eval failed — using host dir names (${#from_dir[@]})"
        printf '%s\n' "${from_dir[@]}"
        return 0
    fi

    debug "nixosConfigurations listing failed (see ${errfile})"
    return 1
}

# Description: True when host is in the newline list (exact match).
nds_flake_host_in_list() {
    local host="$1"
    shift
    local h
    for h in "$@"; do
        [[ "$h" == "$host" ]] && return 0
    done
    return 1
}

# Description: Interactive host picker; sets FLAKE_HOST / NETWORK_HOSTNAME.
# Respects existing FLAKE_HOST / NDS_FLAKE_HOST when it is in the discovered list.
# Arguments:
# - flake_root: <String|optional> Flake path (defaults via nds_flake_resolve_root)
# Returns:
# - 0 on selection, NDS_ACTION_BACK on back, 1 on failure
nds_flake_pick_host() {
    local flake_root="${1:-}"
    local -a hosts=()
    local options labels host default rc existing

    if [[ -z "$flake_root" ]]; then
        flake_root="$(nds_flake_resolve_root)" || {
            error "Flake root required to list nixosConfigurations"
            return 1
        }
    fi

    nds_ui_section_header "Configuration — select host"
    nds_ui_b "Choose a nixosConfigurations attribute from this flake."
    nds_ui_b ""

    if declare -f nds_step_start &>/dev/null; then
        nds_step_start "Listing nixosConfigurations"
        mapfile -t hosts < <(nds_flake_list_hosts "$flake_root")
        if [[ ${#hosts[@]} -gt 0 ]]; then
            nds_step_complete "Listing nixosConfigurations (${#hosts[@]} hosts)"
        else
            nds_step_fail "Listing nixosConfigurations"
        fi
    else
        mapfile -t hosts < <(nds_flake_list_hosts "$flake_root")
    fi

    existing="$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)"
    [[ -z "$existing" ]] && existing="${NDS_FLAKE_HOST:-}"

    if [[ ${#hosts[@]} -eq 0 ]]; then
        warn "Could not list nixosConfigurations — enter host name manually."
        nds_cfg_ask_hostname FLAKE_HOST "nixosConfigurations host name" "$existing" true
        host="$(nds_cfg_get FLAKE_HOST)"
        [[ -n "$host" ]] || return 1
        nds_cfg_set NETWORK_HOSTNAME "$host"
        return 0
    fi

    if [[ -n "$existing" ]]; then
        if nds_flake_host_in_list "$existing" "${hosts[@]}"; then
            nds_cfg_set FLAKE_HOST "$existing"
            nds_cfg_set NETWORK_HOSTNAME "$existing"
            success "Using nixosConfigurations host from env/config: ${existing}"
            return 0
        fi
        warn "FLAKE_HOST='${existing}' is not in nixosConfigurations — pick from the list."
        nds_cfg_set FLAKE_HOST ""
        existing=""
    fi

    options="$(printf '%s|' "${hosts[@]}")"
    options="${options%|}"
    labels=""
    for host in "${hosts[@]}"; do
        labels+="${host}=${host}|"
    done
    labels="${labels%|}"
    default="${hosts[0]}"

    nds_cfg_section_title "nixosConfigurations hosts"
    nds_cfg_ask_numbered_choice FLAKE_HOST "$options" "$labels" "$default" true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    host="$(nds_cfg_get FLAKE_HOST)"
    nds_cfg_set NETWORK_HOSTNAME "$host"
    return 0
}
