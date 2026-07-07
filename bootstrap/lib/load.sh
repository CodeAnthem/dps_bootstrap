#!/usr/bin/env bash
# ==================================================================================================
# NDS - Library loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-07-06
# ==================================================================================================

declare -ga NDS_DEFAULT_PRESET_BUNDLE=(
    disk encryption region network boot access quick platform security
)

nds_configurator_init() {
    debug "Initializing settings manager..."

    nds_preset_catalog_builtin "$SCRIPT_DIR" || {
        fatal "Failed to catalog builtin presets"
        return 1
    }

    nds_preset_enable_bundle "$SCRIPT_DIR" "${NDS_DEFAULT_PRESET_BUNDLE[@]}" || {
        fatal "Failed to enable default preset bundle"
        return 1
    }

    nds_config_seed_defaults

    debug "Settings initialized (${#PRESET_REGISTRY[@]} cataloged, hooks loaded on demand)"
    return 0
}

nds_installation_init() {
    debug "Loading installation stack..."

    nds_import_file "${SCRIPT_DIR}/tools/git/load.sh" || return 1
    nds_git_tools_load "${SCRIPT_DIR}/tools/git" || {
        fatal "Failed to load git tools"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/tools/install/load.sh" || return 1
    nds_install_tools_load "${SCRIPT_DIR}/tools/install" || {
        fatal "Failed to load install tools"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/lib/install/load.sh" || return 1
    nds_install_load "${SCRIPT_DIR}/lib/install" || {
        fatal "Failed to load install modules"
        return 1
    }

    if declare -f nds_install_logs_init &>/dev/null; then
        nds_install_logs_init || true
    fi

    nds_import_file "${SCRIPT_DIR}/tools/flake/load.sh" || return 1
    nds_flake_tools_load "${SCRIPT_DIR}/tools/flake" || {
        fatal "Failed to load flake tools"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/core/install/flake-pipeline.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/core/install/classic-pipeline.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/core/install/flake-install-pipeline.sh" || return 1

    nds_import_file "${SCRIPT_DIR}/tools/nixWriter/load.sh" || return 1
    nds_nixwriter_load "${SCRIPT_DIR}/tools/nixWriter" || {
        fatal "Failed to load nixWriter"
        return 1
    }

    debug "Installation stack loaded"
    return 0
}
