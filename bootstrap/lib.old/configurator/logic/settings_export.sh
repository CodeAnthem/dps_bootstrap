#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-05 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Export Logic
# Feature:       Export configuration to shell script format
# ==================================================================================================

# ----------------------------------------------------------------------------------
# EXPORT LOGIC
# ----------------------------------------------------------------------------------

# Export non-default settings to shell script format
# Usage: nds_cfg_export_nonDefaults [PREFIX]
nds_cfg_export_nonDefaults() {
    local prefix="${1:-NDS_}"
    
    echo "# Config export at $(date +%Y-%m-%d)"
    echo ""
    
    # Group by preset
    local current_preset=""
    
    # Sort settings by preset priority, then by declaration order
    local sorted_settings
    sorted_settings=$(_nds_cfg_sort_settings_by_preset)
    
    while IFS= read -r varname; do
        local preset="${CFG_SETTINGS["${varname}::preset"]}"
        local value="${CFG_SETTINGS["${varname}::value"]:-}"
        local default="${CFG_SETTINGS["${varname}::default"]:-}"
        local exportable="${CFG_SETTINGS["${varname}::exportable"]:-true}"
        
        # Skip if not exportable
        if [[ "$exportable" != "true" ]]; then
            continue
        fi
        
        # Skip if value equals default
        if [[ "$value" == "$default" ]]; then
            continue
        fi
        
        # Print preset header if changed
        if [[ "$preset" != "$current_preset" ]]; then
            [[ -n "$current_preset" ]] && echo ""
            echo "# preset: $preset"
            current_preset="$preset"
        fi
        
        # Export the variable
        echo "export ${prefix}${varname}=\"${value}\""
    done <<< "$sorted_settings"
}

# ----------------------------------------------------------------------------------
# INTERNAL HELPERS
# ----------------------------------------------------------------------------------

# Sort settings by preset priority, then by declaration order within preset
_nds_cfg_sort_settings_by_preset() {
    # Build list with priority:preset:order:varname
    local lines=()
    
    for varname in "${CFG_ALL_SETTINGS[@]}"; do
        local preset="${CFG_SETTINGS["${varname}::preset"]}"
        local priority="${CFG_PRESETS["${preset}::priority"]:-50}"
        local order="${CFG_PRESETS["${preset}::order"]:-}"
        
        # Find position in preset order
        local pos=0
        local idx=0
        for v in $order; do
            if [[ "$v" == "$varname" ]]; then
                pos=$idx
                break
            fi
            ((idx++))
        done
        
        lines+=("${priority}:${preset}:${pos}:${varname}")
    done
    
    # Sort and extract varname
    printf '%s\n' "${lines[@]}" | sort -t: -k1,1n -k2,2 -k3,3n | cut -d: -f4
}

# Export all settings (including defaults)
# Usage: nds_cfg_export_all [PREFIX]
nds_cfg_export_all() {
    local prefix="${1:-NDS_}"
    
    echo "# Config export (all settings) at $(date +%Y-%m-%d)"
    echo ""
    
    for varname in "${CFG_ALL_SETTINGS[@]}"; do
        local value="${CFG_SETTINGS["${varname}::value"]:-}"
        echo "export ${prefix}${varname}=\"${value}\""
    done
}
