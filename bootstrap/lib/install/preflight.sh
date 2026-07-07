#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install pre-flight checks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-07
# Description:   Disk, nix, network, and SSH checks before destructive install steps
# ==================================================================================================

# Verify nix tooling and optional disk/network before install.
# Usage: nds_preflight_install ["disk"] ["remote_repo_url"]
nds_preflight_install() {
    local disk="${1:-}"
    local remote_url="${2:-}"

    if ! command -v nix &>/dev/null; then
        error "nix not found — boot the NixOS live ISO"
        return 1
    fi

    if ! command -v nixos-install &>/dev/null; then
        error "nixos-install not found — boot the NixOS live ISO"
        return 1
    fi

    if [[ -n "$disk" ]]; then
        if [[ ! -b "$disk" ]]; then
            error "Target disk not found: $disk"
            return 1
        fi
    fi

    local uefi bootloader
    uefi=$(nds_config_get "boot" "BOOT_UEFI_MODE" 2>/dev/null || true)
    bootloader=$(nds_config_get "boot" "BOOT_LOADER" 2>/dev/null || true)

    if [[ "$uefi" != "true" && "$bootloader" == "systemd-boot" ]]; then
        error "systemd-boot requires UEFI — pick GRUB in Boot settings or enable UEFI mode"
        return 1
    fi

    if [[ "$uefi" != "true" && "$bootloader" == "refind" ]]; then
        error "rEFInd requires UEFI — pick GRUB in Boot settings or enable UEFI mode"
        return 1
    fi

    if [[ "$uefi" == "true" && ! -d /sys/firmware/efi/efivars ]]; then
        warn "UEFI mode is on but the live ISO is BIOS-booted."
        warn "Reboot the ISO in UEFI mode, or disable UEFI mode and use GRUB."
        if ! nds_skip_menu NDS_PREFLIGHT_WARN_SKIP; then
            nds_askUserToProceed "Continue anyway?" || return 1
        fi
    fi

    if [[ -n "$remote_url" ]]; then
        if [[ "$remote_url" == git@* || "$remote_url" == ssh://* ]]; then
            nds_preflight_ssh_for_git "$remote_url" || return 1
        elif [[ "$remote_url" == http://* || "$remote_url" == https://* ]]; then
            if ! ping -c1 -W3 1.1.1.1 &>/dev/null; then
                warn "Network may be unreachable — SSH git access could fail"
            fi
        fi
    fi

    return 0
}

# Verify operator machine and SSH access before remote nixos-anywhere install.
# Usage: nds_preflight_remote_install "target_ip" ["remote_repo_url"]
nds_preflight_remote_install() {
    local target_ip="$1"
    local remote_url="${2:-}"

    if ! command -v nix &>/dev/null; then
        error "nix not found — install Nix on the operator machine"
        return 1
    fi

    if [[ -z "$target_ip" ]]; then
        error "REMOTE_TARGET_IP is required for remote install"
        return 1
    fi

    if [[ -n "$remote_url" ]]; then
        if [[ "$remote_url" == git@* || "$remote_url" == ssh://* ]]; then
            nds_preflight_ssh_for_git "$remote_url" || return 1
        elif [[ "$remote_url" == http://* || "$remote_url" == https://* ]]; then
            if ! ping -c1 -W3 1.1.1.1 &>/dev/null; then
                warn "Network may be unreachable — SSH git access could fail"
            fi
        fi
    fi

    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        "root@${target_ip}" true 2>/dev/null; then
        debug "SSH reachable: root@${target_ip}"
    else
        warn "Cannot reach root@${target_ip} via SSH (passwordless root login required)"
        if ! nds_skip_menu NDS_PREFLIGHT_WARN_SKIP; then
            nds_askUserToProceed "Continue without verified SSH access?" || return 1
        fi
    fi

    return 0
}

# Remind operator to load SSH keys before git@ clones.
# Usage: nds_preflight_ssh_for_git "git@github.com:org/repo.git"
nds_preflight_ssh_for_git() {
    local repo_url="$1"

    [[ "$repo_url" == git@* || "$repo_url" == ssh://* ]] || return 0

    if ssh-add -l &>/dev/null 2>&1; then
        debug "SSH agent has keys loaded"
        return 0
    fi

    if [[ -f /root/.ssh/id_ed25519 || -f /root/.ssh/id_rsa ]]; then
        warn "Git uses SSH but no keys are loaded in ssh-agent."
        console "  Try: eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/id_ed25519"
        console "  Or ensure /root/.ssh/config points at your git SSH key."
    else
        warn "Git uses SSH ($repo_url) but no git SSH key found under /root/.ssh/"
        console "  Copy or generate a key before cloning a private flake (import / generate / gh in NDS)."
    fi

    if nds_skip_menu NDS_PREFLIGHT_WARN_SKIP; then
        return 0
    fi

    nds_askUserToProceed "Continue without loaded SSH keys?" || return 1
    return 0
}

# Shallow-clone a flake for probing (disko detection, remote actions).
# Reuses the closure-phase clone when available.
# Usage: nds_preflight_probe_flake "git_url"
nds_preflight_probe_flake() {
    local repo_url="$1"
    local probe_dir="${NDS_FLAKE_PROBE_REPO:-}"

    if [[ -f "${probe_dir}/flake.nix" ]]; then
        debug "Reusing session flake clone: ${probe_dir}"
        printf '%s\n' "$probe_dir"
        return 0
    fi

    if ! nds_git_clone_flake_probe "$repo_url"; then
        error "Could not clone $repo_url for probe"
        return 1
    fi

    printf '%s\n' "${NDS_FLAKE_PROBE_REPO}"
    return 0
}

# Return true when host directory contains disko.nix.
# Usage: nds_preflight_flake_has_disko "flake_root" "host" "host_dir_rel"
nds_preflight_flake_has_disko() {
    local flake_root="$1"
    local host="$2"
    local host_dir_rel="${3:-hosts/x86_64-linux}"

    [[ -f "${flake_root}/${host_dir_rel}/${host}/disko.nix" ]] && return 0

    local found
    found=$(find "${flake_root}/${host_dir_rel}/${host}" -maxdepth 2 -name 'disko.nix' -print -quit 2>/dev/null || true)
    [[ -n "$found" ]] && return 0
    return 1
}

# Suggest or set DISK_STRATEGY=flake when the flake owns disko.
# Usage: nds_preflight_apply_disko_strategy "flake_root" "host" "host_dir_rel"
nds_preflight_apply_disko_strategy() {
    local flake_root="$1"
    local host="$2"
    local host_dir_rel="${3:-hosts/x86_64-linux}"
    local current
    current=$(nds_config_get "disk" "DISK_STRATEGY")
    current="${current:-nds}"

    if [[ "$current" != "nds" ]]; then
        return 0
    fi

    if ! nds_preflight_flake_has_disko "$flake_root" "$host" "$host_dir_rel"; then
        return 0
    fi

    info "Flake defines disko.nix for ${host} — switching DISK_STRATEGY to flake"
    nds_install_log "auto: DISK_STRATEGY=flake (flake has disko.nix)"
    CONFIG_DATA[DISK_STRATEGY]="flake"
    export NDS_DISK_STRATEGY="flake"
    return 0
}
