#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-03 | Modified: 2025-11-03
# Description:   NixOS Feature Helpers
# Feature:       Helper functions around NixOS experimental features
# ==================================================================================================

# =============================================================================
# NixOS Feature Helpers
# =============================================================================

# Check if nix command is available and working
nds_nixos_isNixCommandFeatureEnabled() { nix config show > /dev/null 2>&1; }

# Check if a specific experimental feature is enabled
nds_nixos_isExperimentalFeatureEnabled() {
    local feature="$1"
    local features

    features="$(nds_nixos_getExperimentalFeatures)" || return 1

    for f in $features; do
        if [[ "$f" == "$feature" ]]; then
            return 0
        fi
    done
    return 1
}

# Get all enabled experimental features - Returns a space-separated list of experimental features or nothing
nds_nixos_getExperimentalFeatures() {
    if ! nds_nixos_isNixCommandFeatureEnabled; then
        return 1
    fi

    local line
    line=$(nix config show 2>/dev/null | grep "^experimental-features =") || return 1
    echo "${line#experimental-features = }"
    return 0
}


# Show all enabled experimental features
nds_nixos_showExperimentalFeatures() {
    local features
    features=$(nds_nixos_getExperimentalFeatures) || {
        echo "No experimental features found or nix-command disabled."
        return 1
    }
    printf "Enabled experimental features:\n"
    for f in $features; do
        printf " - %s\n" "$f"
    done
}

# Enable experimental features
nds_nixos_enableExperimentalFeature() {
    local feature="$1"
    local current="${NIX_CONFIG:-experimental-features =}"
    case "$current" in
        *"$feature"*) ;; # already present, do nothing
        *) export NIX_CONFIG="$current $feature" ;;
    esac
}
