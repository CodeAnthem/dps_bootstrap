#!/usr/bin/env bash
# ==================================================================================================
# NDS - Validators loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   Load pure validation helpers (no settings store, no UI)
# ==================================================================================================

nds_validators_load() {
    local base="${1:?validators dir}"
    nds_import_file "${base}/primitive/toggle.sh" || return 1
    nds_import_file "${base}/primitive/choice.sh" || return 1
    nds_import_file "${base}/primitive/int.sh" || return 1
    nds_import_file "${base}/network/ip.sh" || return 1
    nds_import_file "${base}/network/mask.sh" || return 1
    nds_import_file "${base}/network/hostname.sh" || return 1
    nds_import_file "${base}/path/path.sh" || return 1
    nds_import_file "${base}/git/url.sh" || return 1
    nds_import_file "${base}/system/username.sh" || return 1
    nds_import_file "${base}/system/disk.sh" || return 1
    nds_import_file "${base}/system/locale.sh" || return 1
    nds_import_file "${base}/system/keyboard.sh" || return 1
    nds_import_file "${base}/system/timezone.sh" || return 1
    return 0
}
