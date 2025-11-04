#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-04 | Modified: 2025-11-04
# Description:   Partition Tools Facade & Loader
# Feature:       Public API for partitioning; validated import of internal logic modules
# ==================================================================================================

# =============================================================================
# FEATURE INITIALIZATION
# =============================================================================
nds_partition_init() {
    # Import with validation
    nds_import_dir "${SCRIPT_DIR}/lib/partitionTools" true || {
        fatal "Failed to load partition tools"
        return 1
    }
    
    success "Partition tools initialized"
    return 0
}


# =============================================================================
# PUBLIC API (no configurator access inside logic modules)
# =============================================================================

# Describe disk state without prompting. Returns symbolic state on stdout:
#  - wiped
#  - empty_parts
#  - has_fs
#  - in_use
nds_partition_get_disk_state() {
    local disk="$1"
    _nds_partition_check_disk_state "$disk"
}

# Prompted guard using formatting lib and AUTO_APPROVE flags
nds_partition_is_disk_ready_to_format() {
    local disk="$1"; [[ -n "$disk" ]] || { error "No disk specified"; return 1; }

    local state
    state=$(_nds_partition_check_disk_state "$disk") || state="unknown"

    section_header "Disk Summary"
    _nds_partition_summarize_disk "$disk"

    local auto_purge
    auto_purge=$(nds_configurator_config_get_env "AUTO_APPROVE_DISK_PURGE" "false")

    case "$state" in
        wiped)
            info "Disk appears wiped (no label/partitions)."
            return 0
            ;;
        empty_parts)
            warn "Disk has partition table and/or empty partitions but no filesystems."
            return 0
            ;;
        has_fs|in_use)
            warn "Detected existing filesystems or mounted partitions on $disk."
            if [[ "${auto_purge}" == "true" || "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
                warn "AUTO-APPROVE is set — proceeding without prompt."
                return 0
            fi
            nds_askUserToProceed "Formatting will DESTROY ALL DATA on $disk. Continue?" && return 0
            return 1
            ;;
        *)
            warn "Unknown disk state; refusing to proceed without confirmation."
            nds_askUserToProceed "Proceed with formatting $disk?" && return 0
            return 1
            ;;
    esac
}

# High-level: run based on configurator values
nds_partition_run_from_config() {
    local strat disk fs_type swap_mib separate_home home_size enc unlock disko_user use_pass
    strat=$(nds_configurator_config_get_env "PARTITION_STRATEGY" "fast")
    disk=$(nds_configurator_config_get_env "DISK_TARGET") || return 1
    fs_type=$(nds_configurator_config_get_env "FS_TYPE" "btrfs")
    swap_mib=$(nds_configurator_config_get_env "SWAP_SIZE_MIB" "0")
    separate_home=$(nds_configurator_config_get_env "SEPARATE_HOME" "false")
    home_size=$(nds_configurator_config_get_env "HOME_SIZE" "20G")
    enc=$(nds_configurator_config_get_env "ENCRYPTION" "true")
    unlock=$(nds_configurator_config_get_env "ENCRYPTION_UNLOCK_MODE" "manual")
    use_pass=$(nds_configurator_config_get_env "ENCRYPTION_USE_PASSPHRASE" "false")
    disko_user=$(nds_configurator_config_get_env "DISKO_USER_FILE" "")

    # Prefer keyfile when passphrase is disabled
    if [[ "$enc" == "true" && "$use_pass" != "true" ]]; then
        unlock="keyfile"
    fi

    nds_partition_is_disk_ready_to_format "$disk" || return 1

    if [[ "$strat" == "fast" ]]; then
        info "Running fast partitioning strategy"
        _nds_partition_manual_create_layout "$disk" "$swap_mib" || return 1

        local root_dev; root_dev=$(_nds_partition_manual_root_device "$disk" "$swap_mib")

        if [[ "$enc" == "true" ]]; then
            info "Encrypting root partition"
            root_dev=$(_nds_partition_manual_encrypt_root "$root_dev" "$unlock") || return 1
        fi

        info "Formatting and mounting root partition"
        _nds_partition_manual_format_and_mount "$disk" "$root_dev" "$fs_type" "$separate_home" || return 1
        info "Setting up swap"
        _nds_partition_manual_setup_swap "$disk" "$swap_mib" || true
        success "Partitioning and mounting (fast) complete"
    else
        info "Running Disko partitioning strategy"
        nds_partition_disko "$disk" "$fs_type" "$swap_mib" "$separate_home" "$home_size" "$enc" "$unlock" "$disko_user"
    fi
}

# Fast/manual facade (no configurator reads inside logic)
nds_partition_fast() {
    local disk="$1" fs_type="$2" swap_mib="$3" separate_home="$4" home_size="$5" enc="$6" unlock="$7"
    _nds_partition_manual_apply "$disk" "$fs_type" "$swap_mib" "$separate_home" "$home_size" "$enc" "$unlock"
}

# Disko facade (template or user file)
nds_partition_disko() {
    local disk="$1" fs_type="$2" swap_mib="$3" separate_home="$4" home_size="$5" enc="$6" unlock="$7" user_file="$8"
    _nds_partition_disko_apply "$disk" "$fs_type" "$swap_mib" "$separate_home" "$home_size" "$enc" "$unlock" "$user_file"
}
