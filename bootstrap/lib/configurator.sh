#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Master Orchestrator
# Feature:       Modular configuration system with auto-discovery and hook-based architecture
# ==================================================================================================

# =============================================================================
# CONFIGURATOR INITIALIZATION
# =============================================================================

nds_cfg_init() {
    info "Initializing configurator v4.1..."
    
    # 1. Load registry (foundation)
    nds_import_file "${SCRIPT_DIR}/lib/configurator/settingsLogic/logic_registry.sh" || {
        fatal "Failed to load registry"
        return 1
    }
    
    # 2. Load settingTypes logic
    nds_import_file "${SCRIPT_DIR}/lib/configurator/settingTypes/settingTypes.sh" || {
        fatal "Failed to load settingTypes logic"
        return 1
    }
    
    # 3. Load all settingTypes (auto-register)
    nds_import_dir "${SCRIPT_DIR}/lib/configurator/settingTypes" false || {
        fatal "Failed to load settingTypes"
        return 1
    }
    
    # 4. Load settingsLogic components
    nds_import_file "${SCRIPT_DIR}/lib/configurator/settingsLogic/settings.sh" || {
        fatal "Failed to load settings logic"
        return 1
    }
    nds_import_file "${SCRIPT_DIR}/lib/configurator/settingsLogic/logic_visibility.sh" || {
        fatal "Failed to load visibility logic"
        return 1
    }
    nds_import_file "${SCRIPT_DIR}/lib/configurator/settingsLogic/logic_envImport.sh" || {
        fatal "Failed to load env import logic"
        return 1
    }
    nds_import_file "${SCRIPT_DIR}/lib/configurator/settingsLogic/logic_export.sh" || {
        fatal "Failed to load export logic"
        return 1
    }
    
    # 5. Load presetsLogic
    nds_import_file "${SCRIPT_DIR}/lib/configurator/presetsLogic/presets.sh" || {
        fatal "Failed to load presets logic"
        return 1
    }
    
    # 6. Load all presets (auto-register settings)
    nds_import_dir "${SCRIPT_DIR}/lib/configurator/presets" false || {
        fatal "Failed to load presets"
        return 1
    }
    
    # 7. Apply environment variable overrides
    nds_cfg_env_import "NDS_"
    
    success "Configurator v4.1 initialized (${#CFG_ALL_SETTINGTYPES[@]} types, ${#CFG_ALL_PRESETS[@]} presets, ${#CFG_ALL_SETTINGS[@]} settings)"
    return 0
}

# =============================================================================
# BACKWARD COMPATIBILITY LAYER (Optional - can be removed later)
# =============================================================================

# Legacy initialization function (redirects to new)
nds_configurator_init() {
    nds_cfg_init "$@"
}
