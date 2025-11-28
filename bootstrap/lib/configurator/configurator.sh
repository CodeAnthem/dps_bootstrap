#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Master Orchestrator
# Feature:       Modular configuration system with auto-discovery and hook-based architecture
# ==================================================================================================

# ----------------------------------------------------------------------------------
# CONFIGURATOR INITIALIZATION
# ----------------------------------------------------------------------------------

nds_cfg_init() {
    info "Initializing configurator v4.1..."
    
    # 1. Load logic (foundation)
    import_dir "${LIB_DIR}/configurator/logic" false || {
        fatal "Failed to load logic"
        return 1
    }
    
    # 2. Load all settingTypes (auto-register)
    import_dir "${LIB_DIR}/configurator/settingTypes" false || {
        fatal "Failed to load settingTypes"
        return 1
    }
    
    # 3. Load all presets (auto-register settings)
    import_dir "${LIB_DIR}/configurator/presets" false || {
        fatal "Failed to load presets"
        return 1
    }
    
    # 4. Apply environment variable overrides
    nds_cfg_env_import "NDS_"
    
    pass "Configurator v4.1 initialized (${#CFG_ALL_SETTINGTYPES[@]} types, ${#CFG_ALL_PRESETS[@]} presets, ${#CFG_ALL_SETTINGS[@]} settings)"
    return 0
}
