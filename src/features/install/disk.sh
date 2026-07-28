#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-28
# Description:   Disk partitioning adapters for NixOS installation
# Feature:       Thin NDS wrapper around standalone partition logic
# ==================================================================================================

# Compatibility alias for machineFacts and legacy call sites.
_nixinstall_disk_part() {
    nds_install_disk_part "$@"
}

# Description: Format root partition using install context (NDS adapter).
# Arguments:
# - partition: <String> Root block partition
_nixinstall_format_luks_from_ctx() {
    local partition="$1"
    local secrets

    nds_install_ctx_ensure
    secrets="${NDS_RUNTIME_DIR:-/tmp/nds_runtime_$$}/secrets"
    nds_install_luks_format_partition "$partition" \
        "${NDS_CTX_ENCRYPTION_PASSWORD}" \
        "${NDS_CTX_ENCRYPTION_KEY}" \
        "$secrets" || return 1
    nds_install_log "LUKS2 formatted on $partition; root fs created"
}

# Description: Partition disk for NixOS installation (NDS adapter).
# Arguments:
# - disk:            <String> Target block device
# - use_encryption:  <Bool> Encrypt root partition
# - uefi_mode:       <Bool|optional> UEFI layout; auto-detect when empty
_nixinstall_partition_disk() {
    local disk="$1"
    local use_encryption="${2:-false}"
    local uefi_mode="${3:-}"

    if [[ "$use_encryption" == "true" ]]; then
        nds_install_partition_disk "$disk" "$use_encryption" "$uefi_mode" "_nixinstall_format_luks_from_ctx"
    else
        nds_install_partition_disk "$disk" "$use_encryption" "$uefi_mode"
    fi
}
