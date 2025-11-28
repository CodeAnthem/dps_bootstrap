#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-05 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Environment Import Logic
# Feature:       Import configuration from environment variables
# ==================================================================================================

# ----------------------------------------------------------------------------------
# ENVIRONMENT IMPORT
# ----------------------------------------------------------------------------------

# Import settings from environment variables
# Usage: nds_cfg_env_import PREFIX
# Example: nds_cfg_env_import "NDS_" will check NDS_HOSTNAME, NDS_TIMEZONE, etc.
nds_cfg_env_import() {
    local prefix="${1:-NDS_}"
    local imported_count=0
    local failed_count=0
    
    debug "Importing configuration from environment (prefix: ${prefix})"
    
    # Iterate all settings
    for varname in "${CFG_ALL_SETTINGS[@]}"; do
        local env_var="${prefix}${varname}"
        
        # Check if environment variable is set
        if [[ -n "${!env_var:-}" ]]; then
            local env_value="${!env_var}"
            
            debug "  Found $env_var=$env_value"
            
            # Apply value (normalize, validate, apply hook)
            if nds_cfg_apply_setting "$varname" "$env_value" "env"; then
                ((imported_count++))
                debug "    ✓ Applied to $varname"
            else
                ((failed_count++))
                error "    ✗ Failed to apply $env_var to $varname"
            fi
        fi
    done
    
    if [[ $imported_count -gt 0 ]]; then
        info "Environment import: $imported_count settings imported, $failed_count failed"
    fi
    
    return 0
}

# Import a single setting from environment
# Usage: nds_cfg_env_import_single VARNAME [PREFIX]
nds_cfg_env_import_single() {
    local varname="$1"
    local prefix="${2:-NDS_}"
    local env_var="${prefix}${varname}"
    
    if [[ -n "${!env_var:-}" ]]; then
        nds_cfg_apply_setting "$varname" "${!env_var}" "env"
    fi
}
