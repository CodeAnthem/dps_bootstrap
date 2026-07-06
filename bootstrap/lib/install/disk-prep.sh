#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disk preparation (partition, mount, hardware gen)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-06
# ==================================================================================================

# Description: Partition and mount target disk from gathered NDS_CTX_* context.
# Arguments:
# - skip_hardware: <Bool> When true, skip hardware/facter generation
nds_nixinstall_auto() {
    local skip_hardware="${1:-false}"

    _nixinstall_gather_context

    log "Starting NixOS installation"
    log "Disk: ${NDS_CTX_DISK} | strategy: ${NDS_CTX_DISK_STRATEGY} | encryption: ${NDS_CTX_ENCRYPTION} | host: ${NDS_CTX_HOSTNAME}"

    if [[ "$NDS_CTX_DISK_STRATEGY" == "flake" ]]; then
        warn "disk strategy 'flake' skips NDS partitioning — use only from flake install with /mnt ready"
        return 0
    fi

    if [[ "$NDS_CTX_DISK_STRATEGY" == "disko" ]]; then
        nds_step_exec "Running disko" nds_partition_run_disko_from_config || return 1
    else
        if [[ "$NDS_CTX_ENCRYPTION" == "true" ]]; then
            nds_step_exec "Generating encryption secrets" _nixinstall_generate_encryption_secrets || return 1
        fi
        nds_step_exec "Partitioning disk" _nixinstall_partition_disk "$NDS_CTX_DISK" "$NDS_CTX_ENCRYPTION" || return 1
        nds_step_exec "Mounting filesystems" _nixinstall_mount_filesystems "$NDS_CTX_ENCRYPTION" || return 1
    fi

    if [[ "$NDS_CTX_ENCRYPTION" == "true" && "$NDS_CTX_REMOTE_UNLOCK" == "true" ]]; then
        nds_step_exec "Setting up initrd SSH keys" _nixinstall_setup_initrd_ssh_keys || return 1
    fi

    if [[ "$skip_hardware" != "true" ]]; then
        nds_step_exec "Generating hardware configuration" _nixinstall_generate_hardware_config || return 1
    fi
    log "NixOS disk preparation completed successfully"
    return 0
}
