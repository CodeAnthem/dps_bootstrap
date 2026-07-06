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
    nds_import_file "${sm_dir}/store.sh" || return 1
    nds_import_file "${sm_dir}/country.sh" || return 1
    nds_import_file "${sm_dir}/ask.sh" || return 1
    nds_import_file "${sm_dir}/preset.sh" || return 1
    nds_import_file "${sm_dir}/menu.sh" || return 1
    return 0
}

# Country validator uses settingsManager country data.
validate_country() {
    local value="$1"
    [[ "$value" =~ ^[A-Za-z]{2}$ ]] || return 1
    nds_country_defaults "${value,,}" &>/dev/null || return 2
    return 0
}
