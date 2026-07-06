#!/usr/bin/env bash
# ==================================================================================================
# NDS - Nix store helpers (live ISO vs install disk)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# Description:   Detect live ISO store limits; use scratch store on /mnt during install builds
# ==================================================================================================

# Description: Free space in MB on the active Nix store (/nix/store on live ISO).
# Returns:
# - <Int> megabytes free (stdout), 0 when unknown
_nds_nix_store_free_mb() {
    df -BM /nix/store 2>/dev/null | awk 'NR==2 { gsub(/M/, "", $4); print $4 + 0 }'
}

# Description: Scratch Nix store on the mounted install disk (large builds on live ISO).
# Returns:
# - <String> store path (stdout)
_nds_nix_build_store_path() {
    printf '/mnt/var/nds-build-store\n'
}

# Description: Append `store = …` to NIX_CONFIG when live ISO store is nearly full.
# Arguments:
# - base_config: <String> Existing NIX_CONFIG value
# Returns:
# - <String> Combined NIX_CONFIG (stdout)
_nds_nix_combined_nix_config() {
    local base_config="${1:-}"
    local store free_mb store_cfg=""

    free_mb=$(_nds_nix_store_free_mb)
    [[ "${free_mb:-0}" -lt 4096 ]] || {
        printf '%s' "$base_config"
        return 0
    }
    [[ -d /mnt ]] || {
        printf '%s' "$base_config"
        return 0
    }

    store=$(_nds_nix_build_store_path)
    mkdir -p "$store"
    if ! nix --store "$store" store ping &>/dev/null 2>&1; then
        info "Live ISO Nix store is small (${free_mb}MB) — builds use ${store} on the install disk"
        nix copy --to "$store" "$(command -v nix)" "$(command -v nixos-install)" 2>/dev/null || true
    fi
    store_cfg="store = ${store}"
    if [[ -n "$base_config" ]]; then
        printf '%s %s' "$base_config" "$store_cfg"
    else
        printf '%s' "$store_cfg"
    fi
}
