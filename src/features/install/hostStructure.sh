#!/usr/bin/env bash
# ==================================================================================================
# NDS - Committed host structure (mounts.nix / boot.nix)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-09 | Modified: 2026-07-09
# Description:   Patch configuration.nix imports; stage committed structural modules for flake eval
# ==================================================================================================

# Description: Filenames that must stay in the flake Git tree (not gitignored).
_nds_install_flake_committed_host_names() {
    printf '%s\n' mounts.nix boot.nix
}

# Description: Ensure configuration.nix imports committed mounts.nix and boot.nix.
# Arguments:
# - host_dir: <String> Host directory (…/hosts/…/hostname)
_nixinstall_ensure_host_imports() {
    local host_dir="$1"
    local cfg="${host_dir}/configuration.nix"
    local tmp

    [[ -f "$cfg" ]] || {
        warn "No configuration.nix in ${host_dir} — skip import patch"
        return 0
    }

    if grep -q './mounts.nix' "$cfg" && grep -q './boot.nix' "$cfg" \
        && ! grep -qE 'mkNdsBoot\.nix|mkRootFs\.nix' "$cfg"; then
        return 0
    fi

    tmp=$(mktemp)
    awk '
        /mkNdsBoot\.nix/ { next }
        /mkRootFs\.nix/ { next }
        /imports = \[/ {
            print
            if (!seen_mounts) { print "    ./mounts.nix"; seen_mounts = 1 }
            if (!seen_boot) { print "    ./boot.nix"; seen_boot = 1 }
            next
        }
        { print }
    ' "$cfg" >"$tmp"
    mv -f "$tmp" "$cfg"
    nds_install_log "host: patched ${cfg} -> ./mounts.nix + ./boot.nix"
    return 0
}

# Description: git add committed structural modules so flake eval sees them.
# Arguments:
# - flake_root: <String> Flake checkout root
# - host_dir:   <String> Host directory
_nds_install_flake_git_stage_committed_files() {
    local flake_root="$1" host_dir="$2"
    local log rel f
    local -a files=()

    [[ -d "${flake_root}/.git" ]] || return 0

    for f in $(_nds_install_flake_committed_host_names); do
        [[ -f "${host_dir}/${f}" ]] && files+=("${host_dir}/${f}")
    done
    [[ -f "${host_dir}/configuration.nix" ]] && files+=("${host_dir}/configuration.nix")
    [[ ${#files[@]} -gt 0 ]] || return 0

    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    {
        printf '\n=== git add committed host structure (mounts.nix / boot.nix) ===\n'
    } >>"$log"

    for rel in "${files[@]}"; do
        rel="${rel#"${flake_root}/"}"
        git -C "$flake_root" add "$rel" >>"$log" 2>&1 || return 1
        nds_install_log "flake: git add ${rel}"
    done
    return 0
}
