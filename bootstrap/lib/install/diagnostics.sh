#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install diagnostics (detail log)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# Description:   Capture command output and install state in NDS_INSTALL_DETAIL_LOG
# ==================================================================================================

# Description: Path to the verbose install detail log.
# Returns:
# - <String> log file path (stdout)
_nds_install_diag_log() {
    printf '%s\n' "${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
}

# Description: Start a labelled diagnostics block in the detail log.
# Arguments:
# - title: <String> Section title
nds_install_diag_section() {
    local title="$1"
    local log

    log="$(_nds_install_diag_log)"
    {
        printf '\n--- DIAG: %s ---\n' "$title"
        date -Iseconds 2>/dev/null || date
    } >>"$log"
}

# Description: Run a command and append stdout/stderr to the detail log.
# Arguments:
# - label: <String> Description of the command
# - cmd:   <String+> Command and arguments
nds_install_diag_run() {
    local label="$1"
    local log rc=0

    shift
    log="$(_nds_install_diag_log)"
    {
        printf '>>> %s\n' "$label"
        printf '$ %s\n' "$*"
        "$@" || rc=$?
        [[ "$rc" -eq 0 ]] || printf '(exit %s)\n' "$rc"
        printf '\n'
    } >>"$log" 2>&1
    return 0
}

# Description: Append fixed lines to the detail log.
# Arguments:
# - label: <String> Block label
# - text:  <String> Body (may contain newlines)
nds_install_diag_lines() {
    local label="$1"
    local text="$2"
    local log

    log="$(_nds_install_diag_log)"
    {
        printf '>>> %s\n' "$label"
        printf '%s\n' "$text"
        printf '\n'
    } >>"$log"
}

# Description: Disk layout after partitioning.
# Arguments:
# - disk: <String> Block device e.g. /dev/sda
nds_install_diag_disk() {
    local disk="${1:-}"

    nds_install_diag_section "disk layout (${disk:-unknown})"
    [[ -n "$disk" ]] || return 0

    nds_install_diag_run "lsblk -f ${disk}" lsblk -f "$disk"
    if command -v parted &>/dev/null; then
        nds_install_diag_run "parted ${disk} print" parted "$disk" print
    fi
    nds_install_diag_run "blkid (partitions on ${disk})" bash -c \
        "blkid ${disk}* 2>/dev/null || true"
}

# Description: Mount table and free space on the install target.
nds_install_diag_mounts() {
    local root

    root="${NDS_NIX_TARGET_ROOT:-/mnt}"
    nds_install_diag_section "target mounts (${root})"

    if command -v findmnt &>/dev/null; then
        nds_install_diag_run "findmnt -R ${root}" findmnt -R "$root"
    else
        nds_install_diag_run "mount | grep ${root}" bash -c \
            "mount | grep -F '${root}' || true"
    fi
    nds_install_diag_run "df -hT ${root} ${root}/boot ${root}/nix" \
        df -hT "$root" "${root}/boot" "${root}/nix" 2>/dev/null || \
        df -hT "$root" "${root}/boot" 2>/dev/null || true
}

# Description: Firmware mode and NDS boot preset values.
nds_install_diag_boot_config() {
    local loader uefi firmware

    loader="$(nds_config_get "boot" "BOOT_LOADER" 2>/dev/null || true)"
    uefi="$(nds_config_get "boot" "BOOT_UEFI_MODE" 2>/dev/null || true)"
    if [[ -d /sys/firmware/efi/efivars ]]; then
        firmware=UEFI
    else
        firmware=BIOS
    fi

    nds_install_diag_section "boot configuration"
    nds_install_diag_lines "preset" \
        "live firmware: ${firmware}
BOOT_UEFI_MODE=${uefi:-unset}
BOOT_LOADER=${loader:-unset}
DISK_TARGET=$(nds_config_get "disk" "DISK_TARGET" 2>/dev/null || echo unset)"
}

# Description: Bootloader files on the target ESP / BIOS paths.
nds_install_diag_boot_artifacts() {
    local root disk

    root="${NDS_NIX_TARGET_ROOT:-/mnt}"
    disk="$(nds_config_get "disk" "DISK_TARGET" 2>/dev/null || true)"

    nds_install_diag_section "bootloader artifacts"
    nds_install_diag_run "ls -la ${root}/boot" ls -la "${root}/boot"
    nds_install_diag_run "ls -la ${root}/boot/grub" \
        bash -c "ls -la '${root}/boot/grub' 2>/dev/null || echo '(no grub dir)'"
    nds_install_diag_run "grub.cfg" \
        bash -c "ls -la '${root}/boot/grub/grub.cfg' 2>/dev/null || echo '(missing)'"
    nds_install_diag_run "EFI tree" \
        bash -c "find '${root}/boot/EFI' -type f 2>/dev/null | head -40 || echo '(no EFI files)'"
    if [[ -n "$disk" && -b "$disk" ]]; then
        nds_install_diag_run "MBR signature (${disk})" bash -c \
            "dd if='${disk}' bs=512 count=1 status=none 2>/dev/null | strings | head -5 || true"
    fi
}

# Description: Nix store, system profile, and scratch-store state on the target.
nds_install_diag_nix_store() {
    local root scratch uri free_mb lines

    root="${NDS_NIX_TARGET_ROOT:-/mnt}"
    scratch="${root}/var/nds-build-store"
    nds_install_diag_section "nix store / system profile"

    free_mb="$(_nds_nix_store_free_mb 2>/dev/null || echo unknown)"
    uri="$(_nds_nix_install_store_uri 2>/dev/null || echo '(ISO store)')"
    nds_install_diag_lines "store routing" \
        "ISO /nix/store free MB: ${free_mb}
install store URI: ${uri}
target root mounted: $(mountpoint -q "$root" 2>/dev/null && echo yes || echo no)
/mnt/nix mount: $(mountpoint -q "${root}/nix" 2>/dev/null && echo yes || echo no)"

    nds_install_diag_run "system profile" \
        bash -c "ls -la '${root}/nix/var/nix/profiles/system' 2>/dev/null || echo '(missing)'"
    nds_install_diag_run "var/nix profiles" \
        bash -c "ls -la '${root}/var/nix/profiles/system' 2>/dev/null || echo '(missing)'"
    nds_install_diag_run "scratch profile" \
        bash -c "ls -la '${scratch}/var/nix/profiles/system' 2>/dev/null || echo '(missing)'"
    nds_install_diag_run "nixos-system paths (target store)" bash -c \
        "ls -d '${root}'/nix/store/*-nixos-system-* 2>/dev/null | head -5 || echo '(none)'"
    nds_install_diag_run "nixos-system paths (scratch store)" bash -c \
        "ls -d '${scratch}'/*-nixos-system-* 2>/dev/null | head -5 || echo '(none)'"
    nds_install_diag_run "run/current-system" \
        bash -c "ls -la '${root}/run/current-system' 2>/dev/null || echo '(missing)'"

    if [[ -e "${root}/nix/var/nix/profiles/system" ]]; then
        nds_install_diag_run "nix path-info system profile" \
            nix --store "$root" path-info -M "${root}/nix/var/nix/profiles/system" 2>/dev/null || true
    fi
}

# Description: Full post-install snapshot for verify and failure analysis.
nds_install_diag_post_install() {
    nds_install_diag_boot_config
    nds_install_diag_mounts
    nds_install_diag_nix_store
    nds_install_diag_boot_artifacts
}

# Description: Contextual snapshot when an install step fails.
# Arguments:
# - step_label: <String> Failed step name from nds_step_exec
nds_install_diag_step_failure() {
    local step_label="$1"
    local disk

    disk="$(nds_config_get "disk" "DISK_TARGET" 2>/dev/null || true)"
    nds_install_diag_section "step failed: ${step_label}"

    case "$step_label" in
        *Partition*|*partition*|*disko*|*Disko*)
            [[ -n "$disk" ]] && nds_install_diag_disk "$disk"
            ;;
        *Mount*|*mount*)
            nds_install_diag_mounts
            ;;
        *Installing\ NixOS*|*nixos-install*)
            nds_install_diag_nix_store
            nds_install_diag_boot_artifacts
            ;;
        *Verifying*)
            nds_install_diag_post_install
            ;;
    esac

    nds_install_diag_post_install
}
