#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-23 | Modified: 2025-11-05
# Description:   SettingType - URL
# Feature:       URL format validation (http, https, git, ssh)
# ==================================================================================================

_url_promptHint() {
    echo "(http://, https://, git://, or ssh://)"
}

_url_validate() {
    local url="$1"
    [[ "$url" =~ ^(https?|git|ssh):// ]]
}

_url_errorCode() {
    echo "Invalid URL (must start with http://, https://, git://, or ssh://)"
}

# Auto-register this settingType
nds_cfg_settingType_register "url"
