#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   NixOS Config Generation - Packages Module
# Feature:       System packages and Nix Flakes configuration
# ==================================================================================================

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_packages_auto() {
    local essential additional flakes
    essential=$(nds_config_get "packages" "ESSENTIAL_PACKAGES")
    additional=$(nds_config_get "packages" "ADDITIONAL_PACKAGES")
    flakes=$(nds_config_get "packages" "ENABLE_FLAKES")
    
    _nixcfg_packages_generate "$essential" "$additional" "$flakes"
}

# Manual mode: explicit parameters
nds_nixcfg_packages() {
    local essential="${1:-vim git curl wget}"
    local additional="${2:-}"
    local flakes="${3:-true}"
    
    _nixcfg_packages_generate "$essential" "$additional" "$flakes"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nixcfg_packages_generate() {
    local essential="$1"
    local additional="$2"
    local flakes="$3"
    
    # Build package list
    local all_packages="$essential"
    if [[ -n "$additional" ]]; then
        all_packages="$all_packages $additional"
    fi
    
    # Convert space-separated to array
    local pkg_array
    IFS=' ' read -ra pkg_array <<< "$all_packages"
    
    local output
    output="environment.systemPackages = with pkgs; ["
    for pkg in "${pkg_array[@]}"; do
        [[ -n "$pkg" ]] && output+="
  $pkg"
    done
    output+="
];

"
    
    # Flakes configuration
    if [[ "$flakes" == "true" ]]; then
        output+="# Enable Nix Flakes
nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];"
    fi
    
    nds_nixcfg_register "packages" "$output" 60
}
