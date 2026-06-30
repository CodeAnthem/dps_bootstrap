#!/usr/bin/env bash
# ==================================================================================================
# NDS - Platform detection
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-06-30
# Description:   Detect virtual machine type on the live ISO
# ==================================================================================================

# Description: Return true when the live system is booted in UEFI mode.
# Returns:
# - <Int> 0 when UEFI firmware is active, 1 for legacy BIOS
nds_platform_is_uefi() {
    [[ -d /sys/firmware/efi/efivars ]]
}

# Description: Detect hypervisor / VM type.
# Returns:
# - <String> none | vmware | qemu | kvm | xen | hyperv | virtualbox | other
nds_platform_detect_virt() {
    local virt=""

    if command -v systemd-detect-virt &>/dev/null; then
        virt=$(systemd-detect-virt -v 2>/dev/null || true)
        case "$virt" in
            none|"") printf 'none'; return 0 ;;
            vmware) printf 'vmware'; return 0 ;;
            qemu) printf 'qemu'; return 0 ;;
            kvm) printf 'kvm'; return 0 ;;
            xen) printf 'xen'; return 0 ;;
            microsoft) printf 'hyperv'; return 0 ;;
            oracle) printf 'virtualbox'; return 0 ;;
            *) printf 'other'; return 0 ;;
        esac
    fi

    if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
        virt=$(tr '[:upper:]' '[:lower:]' < /sys/class/dmi/id/sys_vendor)
        case "$virt" in
            *vmware*) printf 'vmware'; return 0 ;;
            *qemu*|*kvm*) printf 'qemu'; return 0 ;;
            *xen*) printf 'xen'; return 0 ;;
            *microsoft*) printf 'hyperv'; return 0 ;;
            *innotek*|*virtualbox*) printf 'virtualbox'; return 0 ;;
        esac
    fi

    printf 'none'
}

# Description: Human-readable label for a partitioning method value.
# Arguments:
# - strategy: <String> nds | disko | flake
# Returns:
# - <String> Label for UI
nds_disk_strategy_label() {
    case "${1:-nds}" in
        nds) printf 'NDS built-in partitioning (EFI + root)' ;;
        disko) printf 'Disko template' ;;
        flake) printf 'No NDS partitioning (your flake owns disk)' ;;
        *) printf '%s' "$1" ;;
    esac
}
