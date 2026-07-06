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

# Description: Explain common nix build preflight failures from the detail log.
_nds_preflight_diagnose_build_failure() {
    local log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local tail free_mb

    tail=$(tail -40 "$log" 2>/dev/null || true)
    free_mb=$(_nds_nix_store_free_mb)

    if grep -qF 'No space left on device' <<<"$tail"; then
        error "Nix ran out of space on the live ISO store (~${free_mb}MB free) — not your install disk."
        warn "The live ISO keeps its own small /nix/store (often ~1–2GB). Your 100GB target disk is used after partitioning."
        warn "NDS skips the heavy preflight build when the ISO store is tight; the install step uses /mnt/var/nds-build-store."
        return 0
    fi
    if grep -qiE 'Could not read from remote repository|authentication failed|Permission denied \(publickey\)' <<<"$tail"; then
        warn "Build failed — private flake input access (check git SSH key on GitHub)."
        return 0
    fi
    warn "See full log: ${log}"
}
