#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings manager loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# ==================================================================================================

nds_settings_manager_load() {
    local sm_dir="${1:?settingsManager dir}"
    local validators_dir="${2:?validators dir}"

    nds_validators_load "$validators_dir" || return 1
    nds_import_file "${sm_dir}/state/store.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/framework/system-vars/load.sh" || return 1
    nds_system_vars_load "${SCRIPT_DIR}/framework/system-vars" || return 1
    nds_import_file "${sm_dir}/reference/country.sh" || return 1
    nds_import_file "${sm_dir}/validation/country.sh" || return 1
    nds_import_file "${sm_dir}/ui/ask.sh" || return 1
    nds_import_file "${sm_dir}/presets/preset.sh" || return 1
    nds_import_file "${sm_dir}/ui/menu.sh" || return 1
    return 0
}
