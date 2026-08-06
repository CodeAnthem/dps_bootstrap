#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote action entry
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-06
# Description:   Clone a flake and run its .nds/action.sh if present, else fall back to a flake install
# ==================================================================================================

_nds_action_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nds_import_file "${_nds_action_dir}/logic/action_logic.sh" || return 1
nds_import_file "${_nds_action_dir}/ui/preview_prompts.sh" || return 1
unset _nds_action_dir
