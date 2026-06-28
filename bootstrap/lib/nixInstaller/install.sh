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
    
    # Create directory if it doesn't exist
    mkdir -p /mnt/etc/nixos
    
    # Generate hardware configuration
    if ! nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/nixos/hardware-configuration.nix; then
        error "Failed to generate hardware configuration"
    fi
    
    log "Hardware configuration generated at /mnt/etc/nixos/hardware-configuration.nix"
    return 0
}

# Copy a local flake directory onto the mounted target root.
# Usage: _nixinstall_stage_local_flake "local_path" "install_path"
_nixinstall_stage_local_flake() {
    local local_path="$1"
    local install_path="$2"

    if [[ -z "$local_path" || ! -d "$local_path" ]]; then
        error "Local flake path not found: $local_path"
    fi

    log "Copying local flake from $local_path to $install_path"
    mkdir -p "$(dirname "$install_path")"

    if [[ -e "$install_path" ]]; then
        rm -rf "$install_path"
    fi

    cp -a "$local_path" "$install_path" || error "Failed to copy flake to $install_path"
    log "Local flake staged at $install_path"
    return 0
}

# Clone or refresh flake checkout on the mounted target root.
# Usage: _nixinstall_ensure_flake_checkout "repo_url" "install_path"
_nixinstall_ensure_flake_checkout() {
    local repo_url="$1"
    local install_path="$2"

    if [[ -z "$repo_url" ]]; then
        error "Flake repo URL is required"
    fi

    if [[ -z "$install_path" ]]; then
        error "Flake install path is required"
    fi

    log "Ensuring flake checkout at $install_path"

    mkdir -p "$(dirname "$install_path")"

    if [[ -d "${install_path}/.git" ]]; then
        log "Flake checkout already present at $install_path"
        return 0
    fi

    if ! git clone --depth 1 "$repo_url" "$install_path"; then
        error "Failed to clone $repo_url to $install_path"
    fi

    log "Flake cloned to $install_path"
    return 0
}

# Usage: _nixinstall_install_nixos_flake "flake_root" "host_name" ["hardware_placement"]
_nixinstall_install_nixos_flake() {
    local flake_root="$1"
    local host_name="$2"
    local hw_placement="${3:-host-dir}"
    local -a install_args=(--root /mnt --flake "${flake_root}#${host_name}" --no-root-passwd)

    log "Installing NixOS from flake ${flake_root}#${host_name}"

    if [[ ! -d "$flake_root" ]]; then
        error "Flake root not found: $flake_root"
    fi

    if [[ "$hw_placement" == "etc-nixos" && -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
        install_args+=(--override-input hardware "path:/etc/nixos/hardware-configuration.nix")
        log "Using --override-input hardware path:/etc/nixos/hardware-configuration.nix"
    fi

    if ! nixos-install "${install_args[@]}"; then
        error "Flake-based NixOS installation failed"
    fi

    log "Flake-based NixOS installation completed"
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
