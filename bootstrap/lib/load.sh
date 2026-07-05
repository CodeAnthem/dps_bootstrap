#!/usr/bin/env bash
# ==================================================================================================
# NDS - Library loader
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-07-05
# Description:   Load feature packages (config, tools, install, nixcfg)
# ==================================================================================================

nds_configurator_init() {
    debug "Initializing configuration..."

    nds_import_file "${SCRIPT_DIR}/lib/config/store.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/lib/config/validate.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/lib/config/country.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/lib/config/ask.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/lib/config/registry.sh" || return 1
    nds_import_file "${SCRIPT_DIR}/lib/config/menu.sh" || return 1

    nds_config_load_presets || {
        fatal "Failed to load configuration presets"
        return 1
    }

    nds_configurator_preset_disable installFlake
    nds_configurator_preset_disable remoteAction
    nds_config_seed_defaults

    debug "Configuration initialized (${#PRESET_REGISTRY[@]} presets)"
    return 0
}

nds_installation_init() {
    debug "Loading installation stack..."

    nds_import_dir "${SCRIPT_DIR}/lib/install" false || {
        fatal "Failed to load install modules"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/core/flows/flake.sh" || return 1

    nds_import_file "${SCRIPT_DIR}/lib/nixcfg/builder.sh" || {
        fatal "Failed to load nixcfg builder"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/nixcfg/blocks" false || {
        fatal "Failed to load nixcfg blocks"
        return 1
    }

    debug "Installation stack loaded"
    return 0
}
