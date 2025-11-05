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
    
    # 1. Load logic (foundation)
    nds_import_dir "${SCRIPT_DIR}/lib/configurator/logic" false || {
        fatal "Failed to load logic"
        return 1
    }
    
    # 2. Load all settingTypes (auto-register)
    nds_import_dir "${SCRIPT_DIR}/lib/configurator/settingTypes" false || {
        fatal "Failed to load settingTypes"
        return 1
    }
    
    # 3. Load all presets (auto-register settings)
    nds_import_dir "${SCRIPT_DIR}/lib/configurator/presets" false || {
        fatal "Failed to load presets"
        return 1
    }
    
    # 4. Apply environment variable overrides
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
