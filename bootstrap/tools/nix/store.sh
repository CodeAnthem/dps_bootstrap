#!/usr/bin/env bash
# ==================================================================================================
# NDS - Nix store helpers (live ISO vs install disk)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# Description:   Target chroot store on /mnt/nix during install; migrate legacy scratch-store builds
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

# Description: Legacy flat scratch store (pre-5.14.2 builds only).
# Returns:
# - <String> store path (stdout)
_nds_nix_scratch_store_path() {
    printf '%s/var/nds-build-store\n' "$(_nds_nix_target_root)"
}

# Description: True when the target Nix store partition is mounted.
# Returns:
# - <Bool> 0 when /mnt/nix (or NDS_NIX_TARGET_ROOT/nix) is ready
_nds_nix_target_store_mounted() {
    local root
    root=$(_nds_nix_target_root)
    mountpoint -q "${root}/nix" 2>/dev/null || [[ -d "${root}/nix/store" ]]
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
# Prefers chroot store on the mounted target (/mnt → /mnt/nix/store).
# Arguments:
# - base_config: <String> Existing NIX_CONFIG value
# Returns:
# - <String> Combined NIX_CONFIG (stdout)
_nds_nix_combined_nix_config() {
    local base_config="${1:-}"
    local store free_mb store_cfg="" root

    free_mb=$(_nds_nix_store_free_mb)
    [[ "${free_mb:-0}" -lt 4096 ]] || {
        printf '%s' "$base_config"
        return 0
    }

    root=$(_nds_nix_target_root)
    [[ -d "$root" ]] || {
        printf '%s' "$base_config"
        return 0
    }

    if _nds_nix_target_store_mounted; then
        store="$root"
        _nds_nix_ensure_store_ready "$store"
    else
        store=$(_nds_nix_scratch_store_path)
        mkdir -p "$store"
        _nds_nix_ensure_store_ready "$store"
    fi

    store_cfg="store = ${store}"
    if [[ -n "$base_config" ]]; then
        printf '%s\n%s\n' "$base_config" "$store_cfg"
    else
        printf '%s\n' "$store_cfg"
    fi
}

# Description: Move a system built in the legacy scratch store onto /mnt/nix/store.
# Re-runs switch-to-configuration boot so bootloader files point at the target store.
# Returns:
# - <Bool> 0 on success or when nothing to migrate
nds_nix_finalize_install_store() {
    local root scratch profile_dst profile_src system_out nix_config log

    root=$(_nds_nix_target_root)
    profile_dst="${root}/nix/var/nix/profiles/system"
    [[ -e "$profile_dst" ]] && return 0

    scratch=$(_nds_nix_scratch_store_path)
    profile_src="${scratch}/var/nix/profiles/system"
    [[ -e "$profile_src" ]] || return 0

    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"

    info "Migrating NixOS system from scratch store into ${root}/nix/store"
    nix_config=$(_nds_nix_combined_nix_config "experimental-features = nix-command flakes")

    system_out=$(nix --store "$scratch" path-info -M "$profile_src" 2>/dev/null) || {
        error "Cannot resolve system closure in scratch store"
        return 1
    }

    if ! env NIX_CONFIG="$nix_config" nix copy --to "$root" "$system_out" >>"$log" 2>&1; then
        error "Failed to copy system closure to target Nix store"
        return 1
    fi

    mkdir -p "$(dirname "$profile_dst")"
    if ! env NIX_CONFIG="$nix_config" nix-env --store "$root" -p "$profile_dst" --set "$system_out" >>"$log" 2>&1; then
        error "Failed to set system profile on target"
        return 1
    fi

    ln -snf /nix/var/nix/profiles/system "${root}/run/current-system" 2>/dev/null || true

    if ! env NIX_CONFIG="$nix_config" nixos-enter --root "$root" -- \
        '/run/current-system/bin/switch-to-configuration' boot >>"$log" 2>&1; then
        warn "switch-to-configuration boot failed after store migration — check bootloader"
    fi

    nds_install_log "nix: migrated system from scratch store (${system_out})"
    return 0
}
