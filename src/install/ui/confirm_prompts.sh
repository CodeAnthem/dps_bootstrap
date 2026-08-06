#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install UI: shared confirm / section helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_HARDWARE_OVERWRITE_SKIP
declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_SCAFFOLD_OVERWRITE_SKIP

# Description: Section header for flake access verification.
nds_install_ui_section_flake_access() {
    nds_ui_section_header "Verifying flake access"
}

# Description: Confirm overwrite of an existing hardware artifact.
# Arguments:
# - artifact: <String> Filename (e.g. facter.json)
# Returns:
# - 0 when overwrite allowed; 1 when keep existing
nds_install_ui_confirm_hardware_overwrite() {
    local artifact="$1"
    if nds_skip_menu NDS_HARDWARE_OVERWRITE_SKIP; then
        return 0
    fi
    nds_ask_user_to_proceed "Overwrite existing ${artifact}?"
}

# Description: Confirm overwrite of files in a host directory.
# Arguments:
# - host_dir: <String> Absolute host dir path
nds_install_ui_confirm_scaffold_overwrite() {
    local host_dir="$1"
    if nds_skip_menu NDS_SCAFFOLD_OVERWRITE_SKIP; then
        return 0
    fi
    nds_ask_user_to_proceed "Overwrite files in ${host_dir}?"
}

# Description: Section header for the NixOS install phase.
nds_install_ui_section_nixos_install() {
    nds_ui_section_header "NixOS installation"
}
