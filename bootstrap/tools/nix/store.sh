#!/usr/bin/env bash
# ==================================================================================================
# NDS - Nix store helpers (live ISO vs install disk)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# Description:   Chroot store on mounted /mnt during install; repair profile and bootloader after nixos-install
# ==================================================================================================

# Description: Mounted target root (default /mnt).
# Returns:
# - <String> path (stdout)
_nds_nix_target_root() {
    printf '%s\n' "${NDS_NIX_TARGET_ROOT:-/mnt}"
}

# Description: Free space in MB on the active Nix store (/nix/store on live ISO).
# Returns:
# - <Int> megabytes free (stdout), 0 when unknown
_nds_nix_store_free_mb() {
    df -BM /nix/store 2>/dev/null | awk 'NR==2 { gsub(/M/, "", $4); print $4 + 0 }'
}

# Description: Legacy flat scratch store (pre-5.14.3 builds only).
# Returns:
# - <String> store path (stdout)
_nds_nix_scratch_store_path() {
    printf '%s/var/nds-build-store\n' "$(_nds_nix_target_root)"
}

# Description: True when the install target root filesystem is mounted.
# Returns:
# - <Bool> 0 when ready for chroot store builds
_nds_nix_target_root_mounted() {
    [[ "${NDS_NIX_INSTALL_STORE_FORCE:-}" == "1" ]] && return 0
    local root
    root=$(_nds_nix_target_root)
    mountpoint -q "$root" 2>/dev/null
}

# Description: Chroot store URI for install-time nix/nixos-install (e.g. /mnt).
# Returns:
# - <String> store URI (stdout), non-zero when ISO store should be used
_nds_nix_install_store_uri() {
    local root free_mb

    free_mb=$(_nds_nix_store_free_mb)
    [[ "${free_mb:-0}" -lt 4096 ]] || return 1

    root=$(_nds_nix_target_root)
    _nds_nix_target_root_mounted || return 1

    mkdir -p "${root}/nix/store"
    _nds_nix_ensure_store_ready "$root"
    printf '%s\n' "$root"
}

# Description: Optional `--store` arguments for nix CLI (stdout, one arg per line).
_nds_nix_install_store_args() {
    local uri
    uri=$(_nds_nix_install_store_uri 2>/dev/null) || return 0
    printf '%s\n' --store "$uri"
}

# Description: Initialize a chroot or scratch Nix store if needed.
# Arguments:
# - store_uri: <String> Chroot root (/mnt) or scratch store path
_nds_nix_ensure_store_ready() {
    local store_uri="$1"

    [[ -n "$store_uri" ]] || return 0
    if nix --store "$store_uri" store ping &>/dev/null 2>&1; then
        return 0
    fi

    if [[ "$store_uri" == "$(_nds_nix_target_root)" ]]; then
        info "Seeding Nix tools into target store (${store_uri}/nix/store)"
    else
        info "Initializing scratch Nix store at ${store_uri}"
    fi
    nix copy --to "$store_uri" "$(command -v nix)" "$(command -v nixos-install)" 2>/dev/null || true
}

# Description: Append `store = …` to NIX_CONFIG when live ISO store is nearly full.
# Arguments:
# - base_config: <String> Existing NIX_CONFIG value
# Returns:
# - <String> Combined NIX_CONFIG (stdout)
_nds_nix_combined_nix_config() {
    local base_config="${1:-}"
    local store store_cfg="" root uri

    uri=$(_nds_nix_install_store_uri 2>/dev/null) || {
        printf '%s' "$base_config"
        return 0
    }

    store_cfg="store = ${uri}"
    if [[ -n "$base_config" ]]; then
        printf '%s\n%s\n' "$base_config" "$store_cfg"
    else
        printf '%s\n' "$store_cfg"
    fi
}

# Description: NIX_CONFIG for nixos-install (never override its --store /mnt).
# Returns:
# - <String> NIX_CONFIG value (stdout)
_nds_nix_nixos_install_config() {
    printf '%s' "experimental-features = nix-command flakes"
}

# Description: Resolve a built NixOS system closure on the target or scratch store.
# Arguments:
# - root: <String> Target root mount
# Returns:
# - <String> store path (stdout), empty when not found
_nds_nix_find_system_closure() {
    local root="$1" scratch path system_out

    for path in \
        "${root}/nix/var/nix/profiles/system" \
        "${root}/var/nix/profiles/system"; do
        [[ -e "$path" ]] || continue
        system_out=$(nix --store "$root" path-info -M "$path" 2>/dev/null || true)
        [[ -n "$system_out" ]] && {
            printf '%s\n' "$system_out"
            return 0
        }
    done

    scratch=$(_nds_nix_scratch_store_path)
    path="${scratch}/var/nix/profiles/system"
    if [[ -e "$path" ]]; then
        system_out=$(nix --store "$scratch" path-info -M "$path" 2>/dev/null || true)
        [[ -n "$system_out" ]] && {
            printf '%s\n' "$system_out"
            return 0
        }
    fi

    system_out=$(ls -dt "${root}"/nix/store/*-nixos-system-* 2>/dev/null | head -1 || true)
    [[ -n "$system_out" && -d "$system_out" ]] && {
        printf '%s\n' "$system_out"
        return 0
    }

    system_out=$(ls -dt "${scratch}"/*-nixos-system-* 2>/dev/null | head -1 || true)
    [[ -n "$system_out" && -d "$system_out" ]] && {
        printf '%s\n' "$system_out"
        return 0
    }

    return 1
}

# Description: Ensure /mnt/nix/var/nix/profiles/system exists on the target.
# Arguments:
# - root: <String> Target root mount
# Returns:
# - <Bool> 0 on success
_nds_nix_ensure_system_profile() {
    local root="$1" profile_dst system_out scratch log

    profile_dst="${root}/nix/var/nix/profiles/system"
    [[ -e "$profile_dst" ]] && return 0

    system_out=$(_nds_nix_find_system_closure "$root") || return 1
    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"

    scratch=$(_nds_nix_scratch_store_path)
    if [[ "$system_out" != "${root}"/* ]] && [[ -d "$scratch" ]]; then
        info "Copying NixOS system closure into ${root}/nix/store"
        nix copy --to "$root" "$system_out" >>"$log" 2>&1 || return 1
    fi

    mkdir -p "$(dirname "$profile_dst")"
    nix-env --store "$root" -p "$profile_dst" --set "$system_out" >>"$log" 2>&1 || return 1
    nds_install_log "nix: system profile -> ${profile_dst}"
    return 0
}

# Description: Reinstall bootloader when GRUB/EFI files are missing after nixos-install.
# Arguments:
# - root: <String> Target root mount
# Returns:
# - <Bool> 0 on success
_nds_nix_reinstall_bootloader() {
    local root="$1" loader uefi disk log

    loader=$(nds_config_get "boot" "BOOT_LOADER" 2>/dev/null || true)
    loader="${loader:-grub}"
    uefi=$(nds_config_get "boot" "BOOT_UEFI_MODE" 2>/dev/null || true)
    disk=$(nds_config_get "disk" "DISK_TARGET" 2>/dev/null || true)
    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"

    if [[ "$uefi" == "true" ]]; then
        _nds_install_verify_efi_files "$loader" && return 0
    elif [[ -e "${root}/boot/grub/grub.cfg" ]] \
        && _nds_install_verify_grub_bios "$disk"; then
        return 0
    fi

    [[ -e "${root}/nix/var/nix/profiles/system" ]] || return 1

    info "Reinstalling bootloader on target"
    mkdir -p "${root}/etc"
    touch "${root}/etc/NIXOS"
    ln -sfn /proc/mounts "${root}/etc/mtab"
    ln -snf /nix/var/nix/profiles/system "${root}/run/current-system" 2>/dev/null || true

    export mountPoint="$root"
    if ! NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root "$root" -c "$(cat <<'EOF'
set -e
hash -r
/run/current-system/bin/switch-to-configuration boot
EOF
)" >>"$log" 2>&1; then
        return 1
    fi

    nds_install_log "nix: bootloader reinstalled"
    return 0
}

# Description: Remount target /boot when nixos-install tore down mounts.
_nds_nix_remount_target_if_needed() {
    local root enc
    root=$(_nds_nix_target_root)
    mountpoint -q "${root}/boot" 2>/dev/null && return 0
    enc=$(nds_config_get "encryption" "ENCRYPTION" 2>/dev/null || true)
    info "Remounting target filesystems"
    _nixinstall_mount_filesystems "$enc"
}

# Description: Repair system profile and bootloader after nixos-install.
# Returns:
# - <Bool> 0 on success
nds_nix_ensure_install_artifacts() {
    local root

    root=$(_nds_nix_target_root)
    _nds_nix_remount_target_if_needed || return 1
    _nds_nix_ensure_system_profile "$root" || return 1
    _nds_nix_reinstall_bootloader "$root" || {
        warn "Bootloader reinstall failed — system profile is set; check install log"
    }
    return 0
}

# Description: Legacy name — calls nds_nix_ensure_install_artifacts.
nds_nix_finalize_install_store() {
    nds_nix_ensure_install_artifacts "$@"
}
