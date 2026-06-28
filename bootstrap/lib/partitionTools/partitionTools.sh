#!/usr/bin/env bash
# ==================================================================================================
# NDS - Partition tools public API
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-04 | Modified: 2026-06-28
# Description:   Disk partitioning via NDS layout or Disko
# ==================================================================================================

nds_partition_load() {
    local dir="${SCRIPT_DIR}/lib/partitionTools"
    nds_import_file "${dir}/compat.sh" || return 1
    nds_import_file "${dir}/detect.sh" || return 1
    nds_import_file "${dir}/manual.sh" || return 1
    nds_import_file "${dir}/disko.sh" || return 1
    return 0
}

nds_partition_get_disk_state() {
    local disk="$1"
    _nds_partition_check_disk_state "$disk"
}

nds_partition_is_disk_ready_to_format() {
    local disk="$1"
    [[ -n "$disk" ]] || { error "No disk specified"; return 1; }

    local state
    state=$(_nds_partition_check_disk_state "$disk") || state="unknown"

    section_header "Current Disk Layout"
    _nds_partition_summarize_disk "$disk"

    case "$state" in
        wiped|empty_parts) return 0 ;;
        has_fs|in_use)
            warn "Detected existing filesystems or mounted partitions on $disk"
            if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
                return 0
            fi
            nds_askUserToProceed "Formatting will DESTROY ALL DATA on $disk. Continue?" && return 0
            return 1
            ;;
        *)
            nds_askUserToProceed "Proceed with formatting $disk?" && return 0
            return 1
            ;;
    esac
}

# Run Disko from configurator (DISK_STRATEGY=disko).
nds_partition_run_disko_from_config() {
    local disk fs_type swap_mib enc unlock disko_user use_pass separate_home home_size
    disk=$(nds_configurator_config_get_env "DISK_TARGET") || return 1
    fs_type=$(nds_configurator_config_get_env "FS_TYPE" "ext4")
    swap_mib=$(nds_configurator_config_get_env "SWAP_SIZE_MIB" "0")
    separate_home=$(nds_configurator_config_get_env "SEPARATE_HOME" "false")
    home_size=$(nds_configurator_config_get_env "HOME_SIZE" "20G")
    enc=$(nds_configurator_config_get_env "ENCRYPTION" "true")
    unlock="manual"
    use_pass=$(nds_configurator_config_get_env "ENCRYPTION_USE_PASSPHRASE" "false")
    disko_user=$(nds_configurator_config_get_env "DISKO_CONFIG" "")

    if [[ "$enc" == "true" && "$use_pass" != "true" ]]; then
        unlock="keyfile"
    fi

    nds_partition_is_disk_ready_to_format "$disk" || return 1

    run_step "Disko partitioning" \
        _nds_partition_disko_apply "$disk" "$fs_type" "$swap_mib" "$separate_home" "$home_size" "$enc" "$unlock" "$disko_user"
}

nds_partition_disko() {
    _nds_partition_disko_apply "$@"
}
