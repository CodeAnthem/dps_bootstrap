#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-04 | Modified: 2026-07-28
# Description:   Disk partitioning via NDS layout or Disko (public API)
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_DISK_FORMAT_CONFIRM_SKIP

nds_partition_get_disk_state() {
    local disk="$1"
    _install_partition_check_disk_state "$disk"
}

nds_partition_is_disk_ready_to_format() {
    local disk="$1"
    [[ -n "$disk" ]] || { error "No disk specified"; return 1; }

    local state
    state=$(_install_partition_check_disk_state "$disk") || state="unknown"

    nds_ui_section_header "Current Disk Layout"
    _install_partition_summarize_disk "$disk"

    case "$state" in
        wiped|empty_parts) return 0 ;;
        has_fs|in_use)
            warn "Detected existing filesystems or mounted partitions on $disk"
            if nds_skip_menu NDS_DISK_FORMAT_CONFIRM_SKIP; then
                return 0
            fi
            nds_ask_user_to_proceed "Formatting will DESTROY ALL DATA on $disk. Continue?" && return 0
            return 1
            ;;
        *)
            if nds_skip_menu NDS_DISK_FORMAT_CONFIRM_SKIP; then
                return 0
            fi
            nds_ask_user_to_proceed "Proceed with formatting $disk?" && return 0
            return 1
            ;;
    esac
}

# Description: Run Disko with explicit partition parameters.
# Arguments:
# - disk:           <String> Target block device
# - fs_type:        <String> Root filesystem type
# - swap_mib:       <String> Swap size in MiB
# - separate_home:  <Bool> Separate /home partition
# - home_size:      <String> Home partition size
# - enc:            <Bool> LUKS encryption
# - use_pass:       <Bool> Password unlock
# - use_key:        <Bool> Keyfile unlock
# - disko_user:     <String|optional> User disko config path
# Returns:
# - <Bool> 0 on success
nds_partition_run_disko() {
    local disk="$1"
    local fs_type="$2"
    local swap_mib="$3"
    local separate_home="$4"
    local home_size="$5"
    local enc="$6"
    local use_pass="$7"
    local use_key="$8"
    local disko_user="${9:-}"
    local unlock="manual"

    if [[ "$enc" == "true" && "$use_key" == "true" && "$use_pass" != "true" ]]; then
        unlock="keyfile"
    fi

    nds_partition_is_disk_ready_to_format "$disk" || return 1

    nds_step_exec "Disko partitioning" \
        _install_partition_disko_apply "$disk" "$fs_type" "$swap_mib" "$separate_home" "$home_size" "$enc" "$unlock" "$disko_user"
}

# Run Disko from gathered NDS_CTX_* (DISK_STRATEGY=disko).
nds_partition_run_disko_from_config() {
    nds_install_ctx_ensure
    [[ -n "${NDS_CTX_DISK:-}" ]] || { error "DISK_TARGET is required"; return 1; }

    nds_partition_run_disko \
        "$NDS_CTX_DISK" \
        "${NDS_CTX_DISK_FS_TYPE}" \
        "${NDS_CTX_DISK_SWAP_SIZE_MIB}" \
        "${NDS_CTX_SEPARATE_HOME}" \
        "${NDS_CTX_HOME_SIZE}" \
        "${NDS_CTX_ENCRYPTION}" \
        "${NDS_CTX_ENCRYPTION_PASSWORD}" \
        "${NDS_CTX_ENCRYPTION_KEY}" \
        "${NDS_CTX_DISK_DISKO_CONFIG:-}"
}

nds_partition_disko() {
    _install_partition_disko_apply "$@"
}
