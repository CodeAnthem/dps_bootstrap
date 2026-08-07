#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI smoke action entry (debug)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-08-07
# Description:   Interactive prompt walk — no disk wipe / no nixos-install
# ==================================================================================================

_nds_action_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nds_import_file "${_nds_action_dir}/logic/action_logic.sh" || return 1
nds_import_file "${_nds_action_dir}/ui/preview_prompts.sh" || return 1
nds_import_file "${_nds_action_dir}/ui/walk_prompts.sh" || return 1
unset _nds_action_dir
