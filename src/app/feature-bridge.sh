#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action ↔ feature bridge (config AA)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Actions pass mode + config AA into feature entries and merge results
# ==================================================================================================

# Description: Call a feature entry as: fn mode cfg_nameref; merge AA back to store.
# Arguments:
# - fn:   <String> Function name (e.g. nds_git_access_run)
# - args: <String...> Extra args before mode/cfg when fn needs them — not used; prefer AA-only
nds_action_call_feature() {
    local fn="$1"
    shift
    local -A cfg=()
    local mode="${NDS_MODE:-interactive}"

    declare -f "$fn" &>/dev/null || {
        error "Feature entry not found: $fn"
        return 1
    }

    nds_mode_resolve || true
    mode="${NDS_MODE:-interactive}"

    nds_cfg_aa_from_store cfg
    # Optional remaining args are key=value overrides into cfg
    local pair
    for pair in "$@"; do
        [[ "$pair" == *=* ]] || continue
        cfg["${pair%%=*}"]="${pair#*=}"
    done

    "$fn" "$mode" cfg || return $?
    nds_cfg_aa_to_store cfg
    if declare -f nds_cfg_sync_store_to_scoped &>/dev/null; then
        nds_cfg_sync_store_to_scoped || true
    fi
    return 0
}
