#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   NixOS Config Builder Module - System
# Feature:       Generate system configuration (users, locale, timezone)
# ==================================================================================================

# =============================================================================
# PUBLIC API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_system_auto() {
    local admin_user timezone locale_main keyboard
    admin_user=$(nds_config_get "system" "ADMIN_USER")
    timezone=$(nds_config_get "region" "TIMEZONE")
    locale_main=$(nds_config_get "region" "LOCALE_MAIN")
    keyboard=$(nds_config_get "region" "KEYBOARD_LAYOUT")
    
    local block
    block=$(_nixcfg_system_generate "$admin_user" "$timezone" "$locale_main" "$keyboard")
    nds_nixcfg_register "system" "$block" 40
}

# Manual mode: explicit parameters
nds_nixcfg_system() {
    local admin_user="$1"
    local timezone="${2:-UTC}"
    local locale="${3:-en_US.UTF-8}"
    local keyboard="${4:-us}"
    
    local block
    block=$(_nixcfg_system_generate "$admin_user" "$timezone" "$locale" "$keyboard")
    nds_nixcfg_register "system" "$block" 40
}

# =============================================================================
# PRIVATE - Implementation Functions
# =============================================================================

_nixcfg_system_generate() {
    local admin_user="$1"
    local timezone="$2"
    local locale="$3"
    local keyboard="$4"
    
    cat <<EOF
# Time and Locale
time.timeZone = "$timezone";
i18n.defaultLocale = "$locale";
console.keyMap = "$keyboard";

# Users
users.users.$admin_user = {
  isNormalUser = true;
  extraGroups = [ "wheel" "networkmanager" ];
  initialPassword = "changeme";
};

# Sudo for wheel group
security.sudo.wheelNeedsPassword = true;
EOF
}
