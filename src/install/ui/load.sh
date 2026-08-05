#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install UI loader (prompts / display)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# ==================================================================================================

nds_install_ui_load() {
    local ui_dir="${1:?ui dir}"
    # Confirm menus live under app/menus; feature prompts added here as migrated.
    [[ -d "$ui_dir" ]] || return 0
    return 0
}
