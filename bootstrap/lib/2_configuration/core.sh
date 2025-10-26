#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System - Core
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-24
# Description:   Core data structures, registries, and storage
# Dependencies:  None (pure data layer)
# ==================================================================================================
# shellcheck disable=SC2155

# =============================================================================
# GLOBAL STATE
# =============================================================================
# Current module context (set during init) - exported for subshells
declare -gx MODULE_CONTEXT=""

# Field metadata registry: module__field__attribute → value
declare -gA FIELD_REGISTRY 2>/dev/null || true

# Configuration data storage: module__field → value
declare -gA CONFIG_DATA 2>/dev/null || true

# Module registry: stores module callbacks (used by config_use_module)
# shellcheck disable=SC2034
declare -gA MODULE_REGISTRY 2>/dev/null || true

# Input context (set during field_prompt/field_validate)
declare -gx INPUT_CONTEXT_MODULE=""
declare -gx INPUT_CONTEXT_FIELD=""

# Cached options for current input (populated when context is set)
declare -gA INPUT_OPTIONS_CACHE 2>/dev/null || true

# =============================================================================
# FIELD METADATA MANAGEMENT
# =============================================================================

# Declare a field with metadata (uses MODULE_CONTEXT)
# Usage: field_declare HOSTNAME display="Hostname" required=true validator=validate_hostname
field_declare() {
    local field_name="$1"
    shift
    local module="${MODULE_CONTEXT}"
    
    if [[ -z "$module" ]]; then
        error "field_declare called without MODULE_CONTEXT set"
        return 1
    fi
    
    # Parse key=value attributes
    for attr in "$@"; do
        local key="${attr%%=*}"
        local value="${attr#*=}"
        FIELD_REGISTRY["${module}__${field_name}__${key}"]="$value"
    done
    
    # Set default value if provided
    local default="${FIELD_REGISTRY[${module}__${field_name}__default]:-}"
    config_set "$module" "$field_name" "$default"
    
    debug "Field declared: $module.$field_name"
}

# Get field metadata attribute
# Usage: field_get "module" "field" "attribute"
field_get() {
    local module="$1"
    local field="$2"
    local attribute="$3"
    
    echo "${FIELD_REGISTRY[${module}__${field}__${attribute}]:-}"
}

# Check if field exists
# Usage: field_exists "module" "field"
field_exists() {
    local module="$1"
    local field="$2"
    
    [[ -n "${FIELD_REGISTRY[${module}__${field}__display]:-}" ]]
}

# =============================================================================
# CONFIG DATA STORAGE
# =============================================================================

# Set configuration value
# Usage: config_set "module" "field" "value"
config_set() {
    local module="$1"
    local key="$2"
    local value="$3"
    
    CONFIG_DATA["${module}__${key}"]="$value"
    debug "Config set: $module.$key = $value"
}

# Get configuration value
# Usage: config_get "module" "field" OR config_get "field" (uses MODULE_CONTEXT)
config_get() {
    if [[ $# -eq 1 ]]; then
        # Single arg: use MODULE_CONTEXT
        local module="${MODULE_CONTEXT}"
        local key="$1"
    else
        # Two args: explicit module
        local module="$1"
        local key="$2"
    fi
    
    echo "${CONFIG_DATA[${module}__${key}]:-}"
}

# Set action-specific default (respects environment variable priority)
# Usage: config_set_default "module" "field" "value"
# Priority: module default < action default < environment variable
config_set_default() {
    local module="$1"
    local field="$2"
    local value="$3"
    
    # Check if environment variable is set
    local env_var="DPS_${field}"
    local env_value="${!env_var:-}"
    
    # If env var is set, don't override it
    if [[ -n "$env_value" ]]; then
        debug "Action default skipped (env var set): $module.$field (DPS_${field}=${env_value})"
        return 0
    fi
    
    # Set the action-specific default
    config_set "$module" "$field" "$value"
    debug "Action default applied: $module.$field = $value"
}

# Apply DPS_* environment variable overrides for a module
# Usage: config_apply_env_overrides "module"
config_apply_env_overrides() {
    local module="$1"
    
    debug "Scanning for DPS_* environment variable overrides for module: $module"
    
    # Iterate over all fields in this module
    for key in "${!FIELD_REGISTRY[@]}"; do
        # Match pattern: module__FIELD_NAME__display (field name can contain underscores)
        if [[ "$key" =~ ^${module}__(.+)__display$ ]]; then
            local field_name="${BASH_REMATCH[1]}"
            local env_var="DPS_${field_name}"
            
            if [[ -n "${!env_var:-}" ]]; then
                config_set "$module" "$field_name" "${!env_var}"
                log "Environment override: $env_var=${!env_var} -> $module.$field_name"
            fi
        fi
    done
}

# Export configuration as shell variables
# Usage: config_export "module1" "module2" ...
config_export() {
    for module in "$@"; do
        for key in "${!CONFIG_DATA[@]}"; do
            if [[ "$key" =~ ^${module}__(.+)$ ]]; then
                local field_name="${BASH_REMATCH[1]}"
                local value="${CONFIG_DATA[$key]}"
                export "${field_name}=${value}"
                debug "Exported: ${field_name}=${value}"
            fi
        done
    done
}

# =============================================================================
# INPUT CONTEXT HELPERS
# =============================================================================

# Get option for current input with default fallback
# Usage: input_opt "option_name" "default_value"
input_opt() {
    local option_name="$1"
    local default_value="$2"
    
    echo "${INPUT_OPTIONS_CACHE[$option_name]:-$default_value}"
}

# Set input context (used during validation/prompting)
# Usage: set_input_context "module" "field"
set_input_context() {
    local module="$1"
    local field="$2"
    
    INPUT_CONTEXT_MODULE="$module"
    INPUT_CONTEXT_FIELD="$field"
    
    # Cache all options for this field
    INPUT_OPTIONS_CACHE=()
    for key in "${!FIELD_REGISTRY[@]}"; do
        if [[ "$key" =~ ^${module}__${field}__(.+)$ ]]; then
            local attr="${BASH_REMATCH[1]}"
            INPUT_OPTIONS_CACHE["$attr"]="${FIELD_REGISTRY[$key]}"
        fi
    done
}

# Clear input context
clear_input_context() {
    INPUT_CONTEXT_MODULE=""
    INPUT_CONTEXT_FIELD=""
    INPUT_OPTIONS_CACHE=()
}
