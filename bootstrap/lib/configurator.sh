#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-29 | Modified: 2025-10-30
# Description:   Configurator master file - orchestrates config feature
# Feature:       ConfigPreset-based configuration with field validation and interactive prompts
# ==================================================================================================

# =============================================================================
# FEATURE INITIALIZATION
# =============================================================================
nds_configurator_init() {
    info "Initializing configurator..."
    
    # 1. Load config logic files (storage, var, preset, menu)
    nds_source_dir "${SCRIPT_DIR}/lib/config" false || {
        fatal "Failed to load configurator logic"
        return 1
    }
    
    # 2. Load input validators (recursive)
    nds_source_dir "${SCRIPT_DIR}/lib/config/inputs" true || {
        fatal "Failed to load input validators"
        return 1
    }
    
    # 3. Discover, load and initialize presets (single pass)
    for preset_file in "${SCRIPT_DIR}/lib/config/presets/"*.sh; do
        [[ -f "$preset_file" ]] || continue
        
        local preset_name
        preset_name=$(basename "$preset_file" .sh)
        
        # Load preset file (nds_source_dir validates bash)
        nds_source_dir "$(dirname "$preset_file")" false || {
            error "Failed to load preset: $preset_name"
            return 1
        }
        
        # Register preset as enabled by default
        _nds_configurator_preset_register "$preset_name"
        
        # Cache function existence for performance
        _nds_configurator_cache_preset_functions "$preset_name"
        
        # Initialize if enabled
        if _nds_configurator_preset_is_enabled "$preset_name"; then
            _nds_configurator_preset_init "$preset_name" || {
                error "Failed to init preset: $preset_name"
                return 1
            }
        fi
    done
    
    # 4. Apply environment overrides (DPS_*)
    _nds_configurator_apply_env
    
    success "Configurator initialized (${#PRESET_REGISTRY[@]} presets)"
    return 0
}

# =============================================================================
# INTERNAL FUNCTIONS
# =============================================================================

# Register preset with default state
_nds_configurator_preset_register() {
    local preset="$1"
    PRESET_REGISTRY["$preset"]="enabled"
    PRESET_META["${preset}__priority"]="50"
}

# Cache which optional functions exist for this preset
_nds_configurator_cache_preset_functions() {
    local preset="$1"
    
    # Cache get_active function
    if type "${preset}_get_active" &>/dev/null; then
        PRESET_FUNCTIONS["${preset}__get_active"]="true"
    fi
    
    # Cache validate_extra function
    if type "${preset}_validate_extra" &>/dev/null; then
        PRESET_FUNCTIONS["${preset}__validate_extra"]="true"
    fi
}

# Initialize single preset
_nds_configurator_preset_init() {
    local preset="$1"
    PRESET_CONTEXT="$preset"
    
    # Call init function
    local init_func="${preset}_init"
    if type "$init_func" &>/dev/null; then
        $init_func || {
            PRESET_CONTEXT=""
            return 1
        }
    fi
    
    PRESET_CONTEXT=""
    return 0
}

# Apply DPS_* environment variable overrides
_nds_configurator_apply_env() {
    for key in "${!VAR_META[@]}"; do
        if [[ "$key" =~ ^(.+)__display$ ]]; then
            local varname="${BASH_REMATCH[1]}"
            local env_var="DPS_${varname}"
            if [[ -n "${!env_var:-}" ]]; then
                CONFIG_DATA["$varname"]="${!env_var}"
                debug "Env override: $env_var=${!env_var}"
            fi
        fi
    done
}
