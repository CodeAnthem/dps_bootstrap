#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - Path
# Feature:       File/directory path validation
# ==================================================================================================

_path_promptHint() {
    echo "(absolute or relative path)"
}

_path_validate() {
    local path="$1"
    # Accept absolute paths, ~ paths, or ./relative paths
    [[ "$path" =~ ^(/|~|\.) ]]
}

_path_errorCode() {
    echo "Invalid path (must start with /, ~, or .)"
}

# Auto-register this settingType
nds_cfg_settingType_register "path"
