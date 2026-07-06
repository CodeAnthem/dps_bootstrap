#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-04
# Description:   NixOS installation commands
# Feature:       Hardware config generation and nixos-install execution
# ==================================================================================================

# =============================================================================
# NIXOS INSTALLATION
# =============================================================================

# Description: Return hardware artifact filename for the active generation mode.
# Returns:
# - <String> facter.json or hardware-configuration.nix
_nixinstall_hardware_artifact_name() {
    local facter_mode="${NDS_HARDWARE_GEN:-facter}"
    if [[ "$facter_mode" == "facter" ]]; then
        echo "facter.json"
    else
        echo "hardware-configuration.nix"
    fi
}

# Description: Resolve flake root on the operator machine for remote install.
# Arguments:
# - source:     <String> remote | local
# - local_path: <String> Local flake path when source=local
# - repo_url:   <String> Git URL when source=remote
# Returns:
# - <String> Absolute flake root path (stdout)
_nixinstall_resolve_flake_root() {
    local source="$1"
    local local_path="$2"
    local repo_url="$3"
    local install_dir="${NDS_RUNTIME_DIR}/flake_install"

    case "$source" in
        local)
            if [[ -z "$local_path" || ! -d "$local_path" ]]; then
                error "Local flake path not found: $local_path"
            fi
            echo "$local_path"
            ;;
        remote|*)
            if [[ -z "$repo_url" ]]; then
                error "Flake repo URL is required for remote install"
            fi
            if [[ -d "${install_dir}/.git" ]]; then
                echo "$install_dir"
                return 0
            fi
            rm -rf "$install_dir"
            if ! nds_git_clone "$repo_url" "$install_dir" 1; then
                error "Failed to clone $repo_url to $install_dir"
            fi
            echo "$install_dir"
            ;;
    esac
}

# Description: Install NixOS on a remote target via nixos-anywhere.
# Arguments:
# - flake_root: <String> Flake root on the operator machine
# - hostname:   <String> nixosConfigurations name
# - target_ip:  <String> Target host IP or hostname
_nixinstall_via_nixos_anywhere() {
    local flake_root="$1"
    local hostname="$2"
    local target_ip="$3"
    local host_dir_rel="${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}"
    local facter_dest="${flake_root}/${host_dir_rel}/${hostname}/facter.json"
    local -a git_env=() cmd=(
        nix run github:nix-community/nixos-anywhere --
        --flake "${flake_root}#${hostname}"
        --generate-hardware-config nixos-facter "$facter_dest"
        --target-host "root@${target_ip}"
    )
    local encryption
    encryption=$(nds_config_get "encryption" "ENCRYPTION")
    nds_git_export_nix_env git_env
    if [[ "$encryption" == "true" ]]; then
        local key_path="${NDS_RUNTIME_DIR}/secrets/luks_key.bin"
        if [[ ! -f "$key_path" ]]; then
            error "LUKS keyfile not found at $key_path — run encryption secret generation first"
        fi
        cmd+=(--disk-encryption-keys /tmp/luks.key "$key_path")
    fi

    log "Running: ${cmd[*]}"
    if ! env "${git_env[@]}" "${cmd[@]}" 2>&1 | tee -a "$NDS_INSTALL_LOG"; then
        error "nixos-anywhere installation failed"
    fi
    log "Remote install completed — commit ${facter_dest} to your flake repo"
    return 0
}

# Description: Generate facter.json at dest via nixos-facter (live-ISO hardware scan).
# Arguments:
# - dest: <String> Absolute output path (e.g. .../facter.json)
_nixinstall_generate_facter_report() {
    local dest="$1"
    mkdir -p "$(dirname "$dest")"
    log "Generating hardware report via nixos-facter -> ${dest}"
    if ! NIX_CONFIG="experimental-features = nix-command flakes" \
        nix run nixpkgs#nixos-facter -- -o "$dest" \
        >>"${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}" 2>&1; then
        error "nixos-facter failed — see install log for details"
        return 1
    fi
    if [[ ! -s "$dest" ]]; then
        error "nixos-facter did not write ${dest}"
        return 1
    fi
    log "Generated facter.json at ${dest}"
    return 0
}

# Description: Generate legacy hardware-configuration.nix at dest.
# Arguments:
# - dest: <String> Absolute output path
_nixinstall_generate_legacy_hardware() {
    local dest="$1"
    mkdir -p "$(dirname "$dest")"
    log "Generating hardware configuration (legacy) -> ${dest}"
    if ! nixos-generate-config --root /mnt --show-hardware-config > "$dest" \
        >>"${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}" 2>&1; then
        error "Failed to generate hardware configuration"
        return 1
    fi
    if [[ ! -s "$dest" ]]; then
        error "hardware-configuration.nix was not written to ${dest}"
        return 1
    fi
    log "Generated hardware-configuration.nix at ${dest}"
    return 0
}

# Description: Write the hardware artifact for a flake install (host-dir / etc-nixos).
# Arguments:
# - host_dir:      <String> Flake host directory (for host-dir placement)
# - hw_mode:       <String> host-dir | etc-nixos | skip
# - runtime_copy:  <Bool> When true, mirror into $NDS_RUNTIME_DIR/config/ for backup
_nixinstall_place_hardware_artifact() {
    local host_dir="$1"
    local hw_mode="${2:-host-dir}"
    local runtime_copy="${3:-true}"
    local hw_artifact dest

    hw_artifact=$(_nixinstall_hardware_artifact_name)

    case "$hw_mode" in
        skip)
            log "Skipping ${hw_artifact} (FLAKE_HARDWARE_PLACEMENT=skip)"
            return 0
            ;;
        etc-nixos)
            dest="/mnt/etc/nixos/${hw_artifact}"
            ;;
        host-dir|*)
            mkdir -p "$host_dir"
            dest="${host_dir}/${hw_artifact}"
            if [[ -f "$dest" ]]; then
                NDS_UI_QUIET=false
                warn "${hw_artifact} already exists: $dest"
                if ! nds_skip_menu NDS_HARDWARE_OVERWRITE_SKIP; then
                    if ! nds_askUserToProceed "Overwrite existing ${hw_artifact}?"; then
                        log "Keeping existing ${hw_artifact}"
                        NDS_UI_QUIET=true
                        [[ "$runtime_copy" == true ]] && cp "$dest" "${NDS_RUNTIME_DIR}/config/" 2>/dev/null || true
                        return 0
                    fi
                fi
                NDS_UI_QUIET=true
            fi
            ;;
    esac

    if [[ "$hw_artifact" == "facter.json" ]]; then
        _nixinstall_generate_facter_report "$dest"
    else
        _nixinstall_generate_legacy_hardware "$dest"
    fi
    chmod 600 "$dest"

    if [[ "$runtime_copy" == true ]]; then
        mkdir -p "${NDS_RUNTIME_DIR}/config"
        cp "$dest" "${NDS_RUNTIME_DIR}/config/"
    fi
    return 0
}

# Generate hardware configuration
# Usage: _nixinstall_generate_hardware_config
_nixinstall_generate_hardware_config() {
    local hw_artifact
    hw_artifact=$(_nixinstall_hardware_artifact_name)
    mkdir -p /mnt/etc/nixos
    if [[ "$hw_artifact" == "facter.json" ]]; then
        _nixinstall_generate_facter_report "/mnt/etc/nixos/${hw_artifact}"
    else
        _nixinstall_generate_legacy_hardware "/mnt/etc/nixos/${hw_artifact}"
    fi
    return 0
}

# Copy a local flake directory onto the mounted target root.
# Usage: _nixinstall_stage_local_flake "local_path" "install_path"
_nixinstall_stage_local_flake() {
    local local_path="$1"
    local install_path="$2"

    if [[ -z "$local_path" || ! -d "$local_path" ]]; then
        error "Local flake path not found: $local_path"
    fi

    log "Copying local flake from $local_path to $install_path"
    mkdir -p "$(dirname "$install_path")"

    if [[ -e "$install_path" ]]; then
        rm -rf "$install_path"
    fi

    cp -a "$local_path" "$install_path" || error "Failed to copy flake to $install_path"
    log "Local flake staged at $install_path"
    return 0
}

# Clone or refresh flake checkout on the mounted target root.
# Usage: _nixinstall_ensure_flake_checkout "repo_url" "install_path"
_nixinstall_ensure_flake_checkout() {
    local repo_url="$1"
    local install_path="$2"

    if [[ -z "$repo_url" ]]; then
        error "Flake repo URL is required"
    fi

    if [[ -z "$install_path" ]]; then
        error "Flake install path is required"
    fi

    log "Ensuring flake checkout at $install_path"

    mkdir -p "$(dirname "$install_path")"

    if [[ -d "${install_path}/.git" ]]; then
        log "Flake checkout already present at $install_path"
        return 0
    fi

    if ! nds_git_clone "$repo_url" "$install_path" 1; then
        error "Failed to clone $repo_url to $install_path"
    fi

    log "Flake cloned to $install_path"
    return 0
}

# Usage: _nixinstall_install_nixos_flake "flake_root" "host_name" ["hardware_placement"]
_nixinstall_install_nixos_flake() {
    local flake_root="$1"
    local host_name="$2"
    local hw_placement="${3:-host-dir}"
    local -a install_args=(--root /mnt --flake "${flake_root}#${host_name}" --no-root-passwd)
    local -a git_env=()
    local nix_config

    log "Installing NixOS from flake ${flake_root}#${host_name}"

    if [[ ! -d "$flake_root" ]]; then
        error "Flake root not found: $flake_root"
        return 1
    fi

    if [[ "$hw_placement" == "etc-nixos" ]]; then
        local hw_artifact
        hw_artifact=$(_nixinstall_hardware_artifact_name)
        if [[ "$hw_artifact" == "hardware-configuration.nix" && -f /mnt/etc/nixos/hardware-configuration.nix ]]; then
            install_args+=(--override-input hardware "path:/etc/nixos/hardware-configuration.nix")
            log "Using --override-input hardware path:/etc/nixos/hardware-configuration.nix"
        fi
    fi

    nds_git_export_nix_env git_env

    nix_config=$(_nds_nix_combined_nix_config "experimental-features = nix-command flakes")

    if ! env NIX_CONFIG="$nix_config" \
        "${git_env[@]}" nixos-install "${install_args[@]}"; then
        error "Flake-based NixOS installation failed"
        return 1
    fi

    log "Flake-based NixOS installation completed"
    return 0
}

# Copy generated configs from runtime to /mnt/etc/nixos.
# Usage: _nixinstall_install_configs
_nixinstall_install_configs() {
    cp "$NDS_RUNTIME_DIR/config/"*.nix /mnt/etc/nixos/ || return 1

    if [[ -n "${NDS_ACTION_CONFIG_SOURCE:-}" ]] && [[ -f "${NDS_ACTION_CONFIG_SOURCE}" ]]; then
        cp "${NDS_ACTION_CONFIG_SOURCE}" /mnt/etc/nixos/"${NDS_ACTION_CONFIG_FILE:-config.nix}" || return 1
    fi
    return 0
}

# Install NixOS system
# Usage: _nixinstall_install_nixos
_nixinstall_install_nixos() {
    log "Installing NixOS system"

    # Verify configuration exists
    if [[ ! -f /mnt/etc/nixos/configuration.nix ]]; then
        error "No configuration.nix found - run nds_nixcfg_write first"
    fi

    # Run nixos-install
    if ! nixos-install --root /mnt --no-root-passwd; then
        error "NixOS installation failed"
        return 1
    fi

    log "NixOS installation completed"
    return 0
}
