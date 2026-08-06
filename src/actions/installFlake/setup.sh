#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake action entry
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-08-06
# Description:   Install a NixOS host from an existing flake via nixos-install --flake
# ==================================================================================================

_nds_action_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nds_import_file "${_nds_action_dir}/logic/action_logic.sh" || return 1
nds_import_file "${_nds_action_dir}/ui/preview_prompts.sh" || return 1
unset _nds_action_dir
