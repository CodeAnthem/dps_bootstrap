#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-06-27
# Description:   Load disk install, Nix config builder, and legacy setup helpers
# ==================================================================================================

# =============================================================================
# INSTALLATION STACK
# =============================================================================

# Load nixInstaller, nixConfigBuilder, and _nixosSetup libraries (not top-level in lib/).
# Usage: nds_installation_init
nds_installation_init() {
    info "Loading installation stack..."

    nds_import_dir "${SCRIPT_DIR}/lib/nixInstaller" false || {
        fatal "Failed to load nixInstaller"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/nixConfigBuilder" false || {
        fatal "Failed to load nixConfigBuilder"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/nixConfigBuilder/modules" false || {
        fatal "Failed to load nixConfigBuilder modules"
        return 1
    }

    nds_import_dir "${SCRIPT_DIR}/lib/_nixosSetup" false || {
        fatal "Failed to load _nixosSetup"
        return 1
    }

    nds_import_file "${SCRIPT_DIR}/lib/partitionTools/partitionTools.sh" || {
        fatal "Failed to load partitionTools"
        return 1
    }

    nds_partition_load || {
        fatal "Failed to load partition tool modules"
        return 1
    }

    success "Installation stack loaded"
    return 0
}
