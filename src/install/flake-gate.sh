#!/usr/bin/env bash
# ==================================================================================================
# NDS - installFlake early gate (URL → git → hosts → target)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-03
# Description:   Runs after action preview, before settings manager menu
# ==================================================================================================

# Description: Ask flake location if unset (git URL or local path).
_flake_gate_ask_location() {
    local loc src
    loc="$(nds_cfg_get FLAKE_REPO_URL)"
    [[ -z "$loc" ]] && loc="$(nds_cfg_get FLAKE_LOCAL_PATH)"
    [[ -z "$loc" ]] && loc="$(nds_cfg_get FLAKE_LOCATION)"

    if [[ -n "$loc" ]]; then
        src=$(nds_detect_flake_source "$loc")
        nds_cfg_set FLAKE_LOCATION "$loc"
        nds_cfg_set FLAKE_SOURCE "$src"
        if [[ "$src" == remote ]]; then
            nds_cfg_set FLAKE_REPO_URL "$loc"
            nds_cfg_set FLAKE_LOCAL_PATH ""
        else
            nds_cfg_set FLAKE_LOCAL_PATH "$loc"
            nds_cfg_set FLAKE_REPO_URL ""
        fi
        return 0
    fi

    if declare -f _installFlake_ask_location &>/dev/null; then
        _installFlake_ask_location
        return $?
    fi

    nds_cfg_section_title "Your flake"
    nds_cfg_ask_string FLAKE_LOCATION "Flake location (git URL or path)" "" true
    loc="$(nds_cfg_get FLAKE_LOCATION)"
    src=$(nds_detect_flake_source "$loc")
    nds_cfg_set FLAKE_SOURCE "$src"
    if [[ "$src" == remote ]]; then
        nds_cfg_set FLAKE_REPO_URL "$loc"
        nds_cfg_set FLAKE_LOCAL_PATH ""
    else
        nds_cfg_set FLAKE_LOCAL_PATH "$loc"
        nds_cfg_set FLAKE_REPO_URL ""
    fi
}

# Description: Ensure git access for root + flake.lock inputs; returns probe root path.
# Arguments:
# - nameref_out: <Nameref> Receives flake root path used for host listing
_flake_gate_ensure_access() {
    local -n _root_out=$1
    local repo_url local_path probe

    repo_url="$(nds_cfg_get FLAKE_REPO_URL)"
    local_path="$(nds_cfg_get FLAKE_LOCAL_PATH)"

    if [[ -n "$local_path" && -d "$local_path" ]]; then
        nds_git_ensure_flake_closure_access "$local_path" "$repo_url" || return 1
        _root_out="$local_path"
        return 0
    fi

    if [[ -n "$repo_url" ]]; then
        nds_git_ensure_access "$repo_url" || return 1
        nds_ui_section_header "Verifying flake access"
        nds_git_ensure_flake_closure_access "" "$repo_url" || return 1
        probe="${NDS_FLAKE_PROBE_REPO:-}"
        if [[ -n "$probe" && -d "$probe" ]]; then
            _root_out="$probe"
        else
            probe=$(nds_preflight_probe_flake "$repo_url") || return 1
            _root_out="$probe"
        fi
        return 0
    fi

    error "Flake location required"
    return 1
}

# Description: Ask install mode + disk or remote IP.
_flake_gate_ask_target() {
    local mode rc
    nds_cfg_section_title "Install mode"
    nds_cfg_ask_numbered_choice INSTALL_MODE \
        "local|remote" \
        "local=On target (live ISO)|remote=From operator (nixos-anywhere)" \
        "local" \
        true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    mode="$(nds_cfg_get INSTALL_MODE)"
    if [[ "$mode" == "remote" ]]; then
        nds_cfg_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "" true
    else
        if [[ -z "$(nds_cfg_get DISK_TARGET)" ]]; then
            if declare -f nds_cfg_ask_disk &>/dev/null; then
                nds_cfg_ask_disk DISK_TARGET "Target disk" "" true
            else
                nds_cfg_ask_path DISK_TARGET "Target disk (e.g. /dev/sda)" "/dev/sda" true
            fi
        fi
        [[ -z "$(nds_cfg_get DISK_STRATEGY)" ]] && nds_cfg_set DISK_STRATEGY "nds"
    fi
    return 0
}

# Description: Early installFlake gate — URL, git, hosts, target — before config menu.
# Returns:
# - 0 ready for config manager; non-zero abort
nds_flake_install_gate() {
    local flake_root="" rc

    nds_ui_section_header "Flake access gate"

    while true; do
        _flake_gate_ask_location || return 1
        _flake_gate_ensure_access flake_root || return 1

        # Keep-access is asked here even when an existing key skipped the auth wizard.
        if declare -f nds_git_wizard_ask_persist_access &>/dev/null; then
            nds_git_wizard_ask_persist_access
            rc=$?
            [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
            [[ "$rc" -ne 0 ]] && return 1
            if declare -f nds_git_persist_access &>/dev/null && nds_git_persist_access; then
                nds_git_wizard_ask_access_strategy
                rc=$?
                [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
                [[ "$rc" -ne 0 ]] && return 1
            fi
        fi

        # Host + install target are configuration — not part of git access.
        nds_flake_pick_host "$flake_root"
        rc=$?
        if [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]]; then
            nds_cfg_set FLAKE_LOCATION ""
            nds_cfg_set FLAKE_REPO_URL ""
            nds_cfg_set FLAKE_LOCAL_PATH ""
            nds_cfg_set FLAKE_HOST ""
            continue
        fi
        [[ "$rc" -ne 0 ]] && return 1

        _flake_gate_ask_target
        rc=$?
        if [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]]; then
            continue
        fi
        [[ "$rc" -ne 0 ]] && return 1

        # Defaults for remaining flake fields
        [[ -z "$(nds_cfg_get FLAKE_HOST_DIR)" ]] && nds_cfg_set FLAKE_HOST_DIR "hosts/x86_64-linux"
        [[ -z "$(nds_cfg_get FLAKE_INSTALL_PATH)" ]] && nds_cfg_set FLAKE_INSTALL_PATH "/mnt/etc/nixos"
        [[ -z "$(nds_cfg_get FLAKE_HARDWARE_PLACEMENT)" ]] && nds_cfg_set FLAKE_HARDWARE_PLACEMENT "host-dir"

        export NDS_FLAKE_GATE_ROOT="$flake_root"
        return 0
    done
}
