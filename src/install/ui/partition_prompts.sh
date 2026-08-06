#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install UI: disk format confirmations
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_DISK_FORMAT_CONFIRM_SKIP

# Description: Show disk layout and confirm format when needed.
# Arguments:
# - disk:  <String> Target disk
# - state: <String> wiped|empty_parts|has_fs|in_use|…
# Returns:
# - 0 when format may proceed
nds_install_ui_confirm_disk_format() {
    local disk="$1" state="$2"

    nds_ui_section_header "Current Disk Layout"
    declare -f _install_partition_summarize_disk &>/dev/null \
        && _install_partition_summarize_disk "$disk"

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
