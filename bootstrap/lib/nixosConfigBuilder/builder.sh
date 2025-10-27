#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-26 | Modified: 2025-10-26
# Description:   NixOS Configuration Builder - Registry and Merger
# Feature:       Priority-based block assembly for NixOS configuration files
# ==================================================================================================

# =============================================================================
# GLOBAL REGISTRY
# =============================================================================
declare -gA NDS_NIXCFG_BLOCKS
declare -g NDS_NIXCFG_HEADER=""

# =============================================================================
# PRIORITY RANGES (with gaps for injection)
# =============================================================================
# 00-09: Custom headers / file-level attributes
# 10-19: Boot configuration
# 20-29: Network configuration
# 30-39: Disk/filesystem configuration
# 40-49: System configuration (users, locale, timezone)
# 50-59: Services configuration (SSH, firewall)
# 60-69: Packages
# 70-79: Security hardening
# 80-89: Custom blocks
# 90-99: Late-stage overrides

# =============================================================================
# PUBLIC API
# =============================================================================

# Register a configuration block
# Usage: nds_nixcfg_register "block_name" "content" [priority]
# Priority: 0-100 (lower = earlier in file)
nds_nixcfg_register() {
    local block_name="$1"
    local block_content="$2"
    local priority="${3:-50}"
    
    NDS_NIXCFG_BLOCKS["$(printf '%03d' "$priority")_${block_name}"]="$block_content"
    debug "Registered NixOS config block: $block_name (priority: $priority)"
}

# Set custom file header (optional)
# Usage: nds_nixcfg_set_header "# Custom header comment"
nds_nixcfg_set_header() {
    local header="$1"
    NDS_NIXCFG_HEADER="$header"
}

# Merge all registered blocks and write to file
# Usage: nds_nixcfg_write "/mnt/etc/nixos/configuration.nix"
nds_nixcfg_write() {
    local output_file="${1:-/mnt/etc/nixos/configuration.nix}"
    
    # Ensure target directory exists
    mkdir -p "$(dirname "$output_file")"
    
    {
        # Custom header if set
        if [[ -n "$NDS_NIXCFG_HEADER" ]]; then
            echo "$NDS_NIXCFG_HEADER"
            echo ""
        fi
        
        # Standard NixOS header
        echo "{ config, pkgs, ... }:"
        echo ""
        echo "{"
        
        # Output blocks sorted by priority
        for key in $(printf '%s\n' "${!NDS_NIXCFG_BLOCKS[@]}" | sort); do
            local block_name="${key#*_}"
            echo "  # === ${block_name} ==="
            echo "${NDS_NIXCFG_BLOCKS[$key]}" | sed 's/^/  /'
            echo ""
        done
        
        echo "}"
    } > "$output_file"
    
    log "NixOS configuration written to: $output_file"
}

# Clear all registered blocks
# Usage: nds_nixcfg_clear
nds_nixcfg_clear() {
    NDS_NIXCFG_BLOCKS=()
    NDS_NIXCFG_HEADER=""
    debug "Cleared all NixOS config blocks"
}
