#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-05 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Settings Registry Logic
# Feature:       Registration and global lists for settings, presets, and settingTypes
# ==================================================================================================

# ----------------------------------------------------------------------------------
# GLOBAL REGISTRIES
# ----------------------------------------------------------------------------------

# Settings: stores all setting metadata and values
declare -gA CFG_SETTINGS=()

# Presets: stores preset metadata and ordering
declare -gA CFG_PRESETS=()
declare -ga CFG_PRESETS_WITH_ERRORS=()

# SettingTypes: stores settingType function hooks
declare -gA CFG_SETTINGTYPES=()

# Master lists for iteration
declare -ga CFG_ALL_SETTINGS=()
declare -ga CFG_ALL_PRESETS=()
declare -ga CFG_ALL_SETTINGTYPES=()

# ----------------------------------------------------------------------------------
# CONTEXT VARIABLES
# ----------------------------------------------------------------------------------

# Current preset context (set during preset creation)
declare -gx CFG_CONTEXT_PRESET=""

# Current validator context (set during validation)
declare -gx CFG_VALIDATOR_CONTEXT=""

# Apply hook reentrancy stack (prevents infinite loops)
declare -gA CFG_APPLY_STACK=()

# ----------------------------------------------------------------------------------
# SETTINGS REGISTRY API
# ----------------------------------------------------------------------------------

# Check if setting exists
nds_cfg_setting_exists() {
    local var="$1"
    [[ -n "${CFG_SETTINGS["${var}::type"]:-}" ]]
}

# Get all settings
nds_cfg_setting_all() {
    printf '%s\n' "${CFG_ALL_SETTINGS[@]}"
}

# Get setting field value
nds_cfg_setting_get() {
    local var="$1"
    local field="$2"
    echo "${CFG_SETTINGS["${var}::${field}"]:-}"
}

# Set setting field value
nds_cfg_setting_set() {
    local var="$1"
    local field="$2"
    local value="$3"
    local origin="${4:-auto}"
    
    CFG_SETTINGS["${var}::${field}"]="$value"
    
    # Update origin if setting value
    if [[ "$field" == "value" ]]; then
        CFG_SETTINGS["${var}::origin"]="$origin"
    fi
}

# ----------------------------------------------------------------------------------
# PRESETS REGISTRY API
# ----------------------------------------------------------------------------------

# Check if preset exists
nds_cfg_preset_exists() {
    local preset="$1"
    [[ -n "${CFG_PRESETS["${preset}::display"]:-}" ]]
}

# Get all presets
nds_cfg_preset_all() {
    printf '%s\n' "${CFG_ALL_PRESETS[@]}"
}

# Get preset field value
nds_cfg_preset_get() {
    local preset="$1"
    local field="$2"
    echo "${CFG_PRESETS["${preset}::${field}"]:-}"
}

# Set preset field value
nds_cfg_preset_set() {
    local preset="$1"
    local field="$2"
    local value="$3"
    
    CFG_PRESETS["${preset}::${field}"]="$value"
}

# ----------------------------------------------------------------------------------
# SETTINGTYPES REGISTRY API
# ----------------------------------------------------------------------------------

# Get settingType hook function
nds_cfg_settingType_get() {
    local type="$1"
    local hook="$2"
    echo "${CFG_SETTINGTYPES["${type}::${hook}"]:-}"
}

# Check if settingType exists
nds_cfg_settingType_exists() {
    local type="$1"
    [[ -n "${CFG_SETTINGTYPES["${type}::validate"]:-}" ]]
}

# ----------------------------------------------------------------------------------
# UTILITY FUNCTIONS
# ----------------------------------------------------------------------------------

# Clear all registries (for reset/reinit)
nds_cfg_registry_clearAll() {
    CFG_SETTINGS=()
    CFG_PRESETS=()
    CFG_SETTINGTYPES=()
    CFG_ALL_SETTINGS=()
    CFG_ALL_PRESETS=()
    CFG_ALL_SETTINGTYPES=()
    CFG_CONTEXT_PRESET=""
    CFG_VALIDATOR_CONTEXT=""
}
