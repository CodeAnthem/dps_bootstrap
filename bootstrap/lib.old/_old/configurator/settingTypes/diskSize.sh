#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - DiskSize
# Feature:       Disk size format validation (e.g., 8G, 500M, 1T)
# ==================================================================================================

_diskSize_promptHint() {
    echo "(e.g., 8G, 500M, 1T)"
}

_diskSize_validate() {
    local size="$1"
    [[ "$size" =~ ^[0-9]+[KMGT]?$ ]]
}

_diskSize_errorCode() {
    echo "Invalid disk size format (examples: 8G, 500M, 1T, 50G)"
}

# Auto-register this settingType
nds_cfg_settingType_register "diskSize"
