#!/usr/bin/env bash
# ==================================================================================================
# NDS - installFlake early gate (mode + config AA)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-31 | Modified: 2026-08-05
# Description:   URL → git → hosts → target; binds AA for nested prompts
# ==================================================================================================

# Description: Early installFlake gate — mode + config AA (mutates AA).
# Arguments:
# - mode: <String> interactive|unattended
# - cfg:  <Nameref> Full config AA
# Returns:
# - 0 ready for config manager; non-zero abort
nds_flake_install_gate() {
    local mode="${1:-interactive}"
    local -n _fg=$2
    local flake_root="" rc
    local prev_aa="${NDS_CFG_AA_NAME:-}"

    nds_cfg_aa_bind _fg
    nds_ui_section_header "Flake access gate"

    while true; do
        nds_flake_gate_prompts_location || {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }
        nds_flake_gate_logic_ensure_access "$mode" _fg flake_root || {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }

        nds_flake_gate_prompts_persist
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }

        nds_flake_pick_host "$flake_root"
        rc=$?
        if [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]]; then
            nds_cfg_set FLAKE_LOCATION ""
            nds_cfg_set FLAKE_REPO_URL ""
            nds_cfg_set FLAKE_LOCAL_PATH ""
            nds_cfg_set FLAKE_HOST ""
            continue
        fi
        [[ "$rc" -ne 0 ]] && {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }

        nds_flake_gate_prompts_target
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && {
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        }

        nds_flake_gate_logic_seed_defaults
        export NDS_FLAKE_GATE_ROOT="$flake_root"
        NDS_CFG_AA_NAME="$prev_aa"
        return 0
    done
}
