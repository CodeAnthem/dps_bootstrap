#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-27
# Description:   Packages Module - Configuration & NixOS Generation
# Feature:       System packages and Nix configuration, NixOS generation
# ==================================================================================================

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
packages_init_callback() {
    nds_field_declare ESSENTIAL_PACKAGES \
        display="Essential Packages (space-separated)" \
        input=string \
        default="vim git curl wget htop tmux"
    
    nds_field_declare ADDITIONAL_PACKAGES \
        display="Additional Packages (space-separated)" \
        input=string \
        default=""
    
    nds_field_declare ENABLE_FLAKES \
        display="Enable Nix Flakes" \
        input=toggle \
        default=true
}

# Note: No need for packages_get_active_fields() - auto-generates all fields

# =============================================================================
# CONFIGURATION - Cross-Field Validation
# =============================================================================
packages_validate_extra() {
    # No cross-field validation needed
    return 0
}

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_packages_auto() {
    local essential additional flakes
    essential=$(nds_config_get "packages" "ESSENTIAL_PACKAGES")
    additional=$(nds_config_get "packages" "ADDITIONAL_PACKAGES")
    flakes=$(nds_config_get "packages" "ENABLE_FLAKES")
    
    local block
    block=$(_nixcfg_packages_generate "$essential" "$additional" "$flakes")
    nds_nixcfg_register "packages" "$block" 60
}

# Manual mode: explicit parameters
nds_nixcfg_packages() {
    local essential="${1:-vim git curl wget}"
    local additional="${2:-}"
    local flakes="${3:-true}"
    
    local block
    block=$(_nixcfg_packages_generate "$essential" "$additional" "$flakes")
    nds_nixcfg_register "packages" "$block" 60
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nixcfg_packages_generate() {
    local essential="$1"
    local additional="$2"
    local flakes="$3"
    
    local output=""
    
    # Build package list
    local all_packages="$essential"
    if [[ -n "$additional" ]]; then
        all_packages="$all_packages $additional"
    fi
    
    # Convert space-separated to array
    local pkg_array
    IFS=' ' read -ra pkg_array <<< "$all_packages"
    
    output+="environment.systemPackages = with pkgs; [\n"
    for pkg in "${pkg_array[@]}"; do
        [[ -n "$pkg" ]] && output+="  $pkg\n"
    done
    output+="];\n\n"
    
    # Flakes configuration
    if [[ "$flakes" == "true" ]]; then
        output+="# Enable Nix Flakes\n"
        output+="nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];\n"
    fi
    
    echo -e "$output"
}
