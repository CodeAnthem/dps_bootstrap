#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-03 | Modified: 2025-11-03
# Description:   Disk safety checks and confirmation helpers
# Feature:       Assess target disk state and guard destructive actions
# ==================================================================================================

# =============================================================================
# DISK STATE HELPERS
# =============================================================================

pt__lsblk_json() {
    lsblk -J -O "$1" 2>/dev/null || lsblk -J "$1" 2>/dev/null
}

pt_disk_has_label() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    # If lsblk reports a partition table (PTTYPE), consider it labeled
    local out; out=$(lsblk -no PTTYPE "$disk" 2>/dev/null || true)
    [[ -n "$out" ]]
}

pt_disk_has_partitions() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    # Any child block devices indicate partitions
    lsblk -no NAME "$disk" 2>/dev/null | tail -n +2 | grep -q .
}

pt_disk_partitions_have_filesystems() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    # If any child has FSTYPE, it contains data/FS
    lsblk -no FSTYPE "$disk" 2>/dev/null | tail -n +2 | grep -qE "[^[:space:]]"
}

pt_disk_in_use() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    # Mounted children?
    lsblk -no MOUNTPOINT "$disk" 2>/dev/null | tail -n +2 | grep -qE "[^[:space:]]"
}

pt_summarize_disk() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    section_header "Disk Summary: $disk"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk" 2>/dev/null | sed 's/^/  /'
}

# =============================================================================
# MAIN GUARD: READY TO FORMAT
# =============================================================================
# Returns 0 if safe (or user approved), 1 to abort
pt_is_disk_ready_to_format() {
    local disk="$1"; [[ -n "$disk" ]] || { error "No disk specified"; return 1; }

    local has_lbl has_parts has_fs in_use
    has_lbl=false; has_parts=false; has_fs=false; in_use=false

    pt_disk_has_label "$disk" && has_lbl=true
    pt_disk_has_partitions "$disk" && has_parts=true
    pt_disk_partitions_have_filesystems "$disk" && has_fs=true
    pt_disk_in_use "$disk" && in_use=true

    pt_summarize_disk "$disk"

    # Auto-approve override
    local auto_purge
    auto_purge=$(nds_configurator_config_get_env "AUTO_APPROVE_DISK_PURGE" "false")

    if [[ "$has_lbl" == false && "$has_parts" == false ]]; then
        info "Disk appears wiped (no label/partitions)."
        return 0
    fi

    if [[ "$has_fs" == false && "$in_use" == false ]]; then
        warn "Disk has partition table and/or empty partitions but no filesystems."
        return 0
    fi

    warn "Detected existing filesystems or mounted partitions on $disk."
    if [[ "$auto_purge" == "true" ]]; then
        warn "AUTO_APPROVE_DISK_PURGE=true — proceeding without prompt."
        return 0
    fi

    nds_askUserToProceed "Formatting will DESTROY ALL DATA on $disk. Continue?" && return 0
    return 1
}
