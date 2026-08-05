#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake gate prompts (interactive; writes via bound nds_cfg_*)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

# Description: Prompt for flake location when unset; normalize into FLAKE_*.
nds_flake_gate_prompts_location() {
    local loc src

    if nds_flake_gate_logic_existing_location; then
        return 0
    fi

    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        error "Unattended mode requires FLAKE_REPO_URL or FLAKE_LOCAL_PATH"
        return 1
    fi

    if declare -f _installFlake_ask_location &>/dev/null; then
        _installFlake_ask_location
        return $?
    fi

    nds_cfg_section_title "Your flake"
    nds_aa_ask_string FLAKE_LOCATION "Flake location (git URL or path)" "" true
    loc="$(nds_feat_cfg_get FLAKE_LOCATION)"
    nds_flake_gate_logic_normalize_location "$loc"
}

# Description: Prompt install mode + disk or remote IP (interactive).
nds_flake_gate_prompts_target() {
    local mode rc

    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        nds_flake_gate_logic_target_unattended
        return $?
    fi

    nds_cfg_section_title "Install mode"
    nds_aa_ask_numbered_choice INSTALL_MODE \
        "local|remote" \
        "local=On target (live ISO)|remote=From operator (nixos-anywhere)" \
        "local" \
        true
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"

    mode="$(nds_feat_cfg_get INSTALL_MODE)"
    if [[ "$mode" == "remote" ]]; then
        nds_aa_ask_ip REMOTE_TARGET_IP "Target host IP or hostname" "" true
    else
        if [[ -z "$(nds_feat_cfg_get DISK_TARGET)" ]]; then
            if declare -f nds_aa_ask_disk &>/dev/null; then
                nds_aa_ask_disk DISK_TARGET "Target disk" "" true
            else
                nds_aa_ask_path DISK_TARGET "Target disk (e.g. /dev/sda)" "/dev/sda" true
            fi
        fi
        [[ -z "$(nds_feat_cfg_get DISK_STRATEGY)" ]] && nds_feat_cfg_set DISK_STRATEGY "nds"
    fi
    return 0
}

# Description: Persist-access / strategy asks (skipped when unattended).
nds_flake_gate_prompts_persist() {
    local rc
    declare -f nds_git_wizard_ask_persist_access &>/dev/null || return 0

    if declare -f nds_mode_is_unattended &>/dev/null && nds_mode_is_unattended; then
        [[ -z "$(nds_feat_cfg_get GIT_PERSIST_ACCESS)" ]] && nds_feat_cfg_set GIT_PERSIST_ACCESS "true"
        return 0
    fi

    nds_git_wizard_ask_persist_access
    rc=$?
    [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
    [[ "$rc" -ne 0 ]] && return 1
    if declare -f nds_git_persist_access &>/dev/null && nds_git_persist_access; then
        nds_git_wizard_ask_access_strategy
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && return "$rc"
        [[ "$rc" -ne 0 ]] && return 1
    fi
    return 0
}
