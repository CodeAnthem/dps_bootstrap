#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2025-10-29
# Description:   Configuration system master file - entry point for config feature
# Feature:       Category-based configuration with field validation and interactive prompts
# ==================================================================================================

# =============================================================================
# LOAD CONFIGURATION SYSTEM
# =============================================================================

# Source configuration logic files (data layer, field ops, category ops, public API)
nds_source_dir "${SCRIPT_DIR}/lib/config" false || {
    fatal "Failed to load configuration system"
    return 1
}

# =============================================================================
# INITIALIZE CONFIGURATION SYSTEM
# =============================================================================

# Initialize all standard categories - called by main.sh before sourcing action setup.sh
nds_config_init_system() {
    local categories=("quick" "access" "network" "disk" "boot" "security" "region")
    
    for category in "${categories[@]}"; do
        _nds_config_init_category "$category" || {
            error "Failed to initialize category: $category"
            return 1
        }
    done
    
    return 0
}

# =============================================================================
# INTERNAL: INITIALIZE SINGLE CATEGORY
# =============================================================================

# Initialize a single category by sourcing its file and calling init callback
_nds_config_init_category() {
    local category="$1"
    
    # Set context
    MODULE_CONTEXT="$category"
    
    # Source category file
    local category_file="${SCRIPT_DIR}/lib/config/categories/${category}/${category}.sh"
    if [[ -f "$category_file" ]]; then
        # shellcheck disable=SC1090
        source "$category_file" || {
            error "Failed to source category file: $category_file"
            return 1
        }
    else
        error "Category file not found: $category_file"
        return 1
    fi
    
    # Call init callback if exists
    local init_callback="${category}_init_callback"
    if type "$init_callback" &>/dev/null; then
        $init_callback || {
            error "Failed to run init callback for category: $category"
            return 1
        }
    fi
    
    # Clear context
    MODULE_CONTEXT=""
    
    return 0
}
