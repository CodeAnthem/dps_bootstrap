#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   NixOS installation commands
# Feature:       Hardware config generation and nixos-install execution
# ==================================================================================================

# =============================================================================
# NIXOS INSTALLATION
# =============================================================================

# Generate hardware configuration
# Usage: _nixinstall_generate_hardware_config
_nixinstall_generate_hardware_config() {
    log "Generating hardware configuration"
    
    if ! nixos-generate-config --root /mnt; then
        error "Failed to generate hardware configuration"
    fi
    
    log "Hardware configuration generated at /mnt/etc/nixos/hardware-configuration.nix"
    return 0
}

# Install NixOS system
# Usage: _nixinstall_install_nixos
_nixinstall_install_nixos() {
    log "Installing NixOS system"
    
    # Verify configuration exists
    if [[ ! -f /mnt/etc/nixos/configuration.nix ]]; then
        error "No configuration.nix found - run nds_nixcfg_write first"
    fi
    
    # Run nixos-install
    if ! nixos-install --root /mnt --no-root-passwd; then
        error "NixOS installation failed"
    fi
    
    log "NixOS installation completed"
    return 0
}
