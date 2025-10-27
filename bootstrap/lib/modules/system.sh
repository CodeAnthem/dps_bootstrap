#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-27
# Description:   System Module - Configuration & NixOS Generation
# Feature:       Hostname, admin user, shell, system-level settings and NixOS generation
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
system_init_callback() {
    # MODULE_CONTEXT is already set to "system"
    
    # System Identity
    nds_field_declare HOSTNAME \
        display="Hostname" \
        input=hostname \
        required=true
    
    # Admin User Settings
    nds_field_declare ADMIN_USER \
        display="Admin Username" \
        input=username \
        default="admin" \
        required=true
    
    nds_field_declare ADMIN_SHELL \
        display="Admin Shell" \
        input=choice \
        default="bash" \
        options="bash|zsh|fish|sh"
    
    nds_field_declare ADMIN_GROUPS \
        display="Additional Groups" \
        input=string \
        default="wheel,docker,networkmanager"
    
    # System Settings
    nds_field_declare AUTO_UPGRADE \
        display="Automatic System Updates" \
        input=toggle \
        default=true
    
    nds_field_declare DEFAULT_EDITOR \
        display="Default System Editor" \
        input=choice \
        default="vim" \
        options="vim|nano|emacs|helix|nvim"
}

# Note: No need for system_get_active_fields() - auto-generates all fields
# Note: No need for system_validate_extra() - no cross-field validation

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_system_auto() {
    local admin_user admin_shell admin_groups timezone locale_main keyboard
    admin_user=$(nds_config_get "system" "ADMIN_USER")
    admin_shell=$(nds_config_get "system" "ADMIN_SHELL")
    admin_groups=$(nds_config_get "system" "ADMIN_GROUPS")
    timezone=$(nds_config_get "region" "TIMEZONE")
    locale_main=$(nds_config_get "region" "LOCALE_MAIN")
    keyboard=$(nds_config_get "region" "KEYBOARD_LAYOUT")
    
    local block
    block=$(_nixcfg_system_generate "$admin_user" "$admin_shell" "$admin_groups" "$timezone" "$locale_main" "$keyboard")
    nds_nixcfg_register "system" "$block" 40
}

# Manual mode: explicit parameters
nds_nixcfg_system() {
    local admin_user="$1"
    local admin_shell="${2:-bash}"
    local admin_groups="${3:-wheel,networkmanager}"
    local timezone="${4:-UTC}"
    local locale="${5:-en_US.UTF-8}"
    local keyboard="${6:-us}"
    
    local block
    block=$(_nixcfg_system_generate "$admin_user" "$admin_shell" "$admin_groups" "$timezone" "$locale" "$keyboard")
    nds_nixcfg_register "system" "$block" 40
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nixcfg_system_generate() {
    local admin_user="$1"
    local admin_shell="$2"
    local admin_groups="$3"
    local timezone="$4"
    local locale="$5"
    local keyboard="$6"
    
    # Convert comma-separated groups to Nix array format
    local groups_array
    IFS=',' read -ra groups_array <<< "$admin_groups"
    local groups_nix=""
    for group in "${groups_array[@]}"; do
        groups_nix+="\"$group\" "
    done
    
    cat <<EOF
# Time and Locale
time.timeZone = "$timezone";
i18n.defaultLocale = "$locale";
console.keyMap = "$keyboard";

# Admin User
users.users.$admin_user = {
  isNormalUser = true;
  extraGroups = [ $groups_nix ];
  shell = pkgs.$admin_shell;
  initialPassword = "changeme";
};

# Sudo for wheel group
security.sudo.wheelNeedsPassword = true;
EOF
}
