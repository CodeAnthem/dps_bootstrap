#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install-time backup bundle
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-30
# Description:   End-of-install zip (keys, config export, logs) for off-machine copy
# ==================================================================================================

# SSH login user on the live ISO (not root).
nds_install_ssh_user() {
    local user="${SUDO_USER:-nixos}"
    [[ "$user" == root ]] && user=nixos
    printf '%s' "$user"
}

# Best-effort IP the user connected to for copy-paste scp/ssh commands.
nds_install_bundle_host_ip() {
    local host=""
    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        read -r _ _ host _ <<< "$SSH_CONNECTION"
    elif command -v ip &>/dev/null; then
        host=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") print $(i+1); exit}')
    fi
    host="${host:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
    printf '%s' "$host"
}

nds_secrets_list_runtime() {
    local item

    if [[ -d "${NDS_RUNTIME_DIR:-}/secrets" ]]; then
        for item in "${NDS_RUNTIME_DIR}/secrets"/*; do
            [[ -f "$item" ]] && echo "$item"
        done
    fi

    if [[ -n "${NDS_KEY_FILE:-}" && -f "$NDS_KEY_FILE" ]]; then
        echo "$NDS_KEY_FILE"
    fi

    if [[ -f /tmp/luks_key.txt ]]; then
        echo "/tmp/luks_key.txt"
    fi
}

# Build bundle path under the nixos home directory.
nds_install_bundle_path() {
    local user hostname stamp name
    user=$(nds_install_ssh_user)
    hostname=$(nds_config_get "network" "HOSTNAME" 2>/dev/null || true)
    hostname="${hostname:-nixos}"
    printf -v stamp '%(%Y%m%d_%H%M%S)T' -1
    name="nds_install_backup_${stamp}_${hostname}.zip"
    printf '/home/%s/%s' "$user" "$name"
}

# Create install backup zip in /home/nixos (owned by nixos for scp/ssh copy).
# Sets NDS_INSTALL_BUNDLE. Silent — no prompts.
nds_install_bundle_create() {
    local staging bundle_path user item secret_files=()
    local detail_log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"

    if [[ -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        return 0
    fi

    user=$(nds_install_ssh_user)
    bundle_path=$(nds_install_bundle_path)
    staging=$(mktemp -d "${TMPDIR:-/tmp}/nds-bundle-staging.XXXXXX") || return 1

    mkdir -p "${staging}/secrets" "${staging}/config" "${staging}/logs"

    mapfile -t secret_files < <(nds_secrets_list_runtime)
    for item in "${secret_files[@]}"; do
        [[ -f "$item" ]] && cp "$item" "${staging}/secrets/"
    done

    nds_configurator_config_export_script > "${staging}/config/nds-config.env"

    if [[ -f "${NDS_RUNTIME_DIR:-}/config/configuration.nix" ]]; then
        cp "${NDS_RUNTIME_DIR}/config/configuration.nix" "${staging}/config/"
    fi
    if [[ -f "${NDS_RUNTIME_DIR:-}/config/hardware-configuration.nix" ]]; then
        cp "${NDS_RUNTIME_DIR}/config/hardware-configuration.nix" "${staging}/config/"
    fi

    [[ -f "$detail_log" ]] && cp "$detail_log" "${staging}/logs/install-detail.log"
    [[ -f "${NDS_INSTALL_LOG:-/tmp/nds_install.log}" ]] && \
        cp "${NDS_INSTALL_LOG}" "${staging}/logs/nds-install.log"

    cat > "${staging}/README.txt" <<EOF
NDS install backup package
Hostname: $(nds_config_get "network" "HOSTNAME" 2>/dev/null || echo unknown)
Created: $(date -Iseconds 2>/dev/null || date)

Contents:
  config/nds-config.env     — paste before a future NDS run
  config/*.nix              — generated configs (if present)
  secrets/                  — LUKS keys (if encryption was enabled)
  logs/                     — install logs
EOF

    mkdir -p "/home/${user}"
    if command -v zip &>/dev/null; then
        (cd "$staging" && zip -r -q "$bundle_path" .) || {
            rm -rf "$staging"
            error "Failed to create install backup: $bundle_path"
            return 1
        }
    else
        bundle_path="${bundle_path%.zip}.tar.gz"
        tar czf "$bundle_path" -C "$staging" . || {
            rm -rf "$staging"
            error "Failed to create install backup: $bundle_path"
            return 1
        }
    fi
    rm -rf "$staging"

    # Owner only — avoids "invalid group" on live ISOs where the user's group
    # is not named after the user (e.g. nixos → users/nogroup).
    chown "$user" "$bundle_path" 2>/dev/null || true
    chmod 600 "$bundle_path"

    export NDS_INSTALL_BUNDLE="$bundle_path"
    export NDS_SECRETS_BUNDLE="$bundle_path"
    nds_install_log "install backup bundle: $bundle_path"
    return 0
}

# Description: Print a colored line in the given ANSI color (no-op without color).
# Arguments:
# - color: <String> ANSI code (e.g. 32 for green, 35 for magenta, 31 for red)
# - text:  <String> Message
_nds_ui_colored() {
    local color="$1"
    local text="$2"
    nds_ui_init
    if [[ "$NDS_UI_COLOR" == true ]]; then
        printf '%s\033[%sm%s\033[0m\n' "$NDS_UI_INDENT_B" "$color" "$text" >&2
    else
        printf '%s%s\n' "$NDS_UI_INDENT_B" "$text" >&2
    fi
}

_nds_install_bundle_remote_copy_hint() {
    local bundle_path="$1"
    local ssh_user host bundle_name

    ssh_user=$(nds_install_ssh_user)
    host=$(nds_install_bundle_host_ip)
    bundle_name=$(basename "$bundle_path")
    [[ -z "$host" ]] && return 0

    nds_ui_h "SCP:"
    nds_ui_i "scp ${ssh_user}@${host}:${bundle_path} ."
    nds_ui_b ""
    nds_ui_h "SSH:"
    nds_ui_i "ssh ${ssh_user}@${host} \"cat ${bundle_path}\" > ${bundle_name}"
    nds_ui_b ""
}

# Post-install screen: success banner, bundle path, copy commands, reboot prompt.
nds_install_bundle_finish() {
    local bundle_ok=1
    nds_install_bundle_create || bundle_ok=0

    new_section
    _nds_ui_colored 32 "Installation successful."

    if [[ "$bundle_ok" -ne 0 && -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        nds_ui_b ""
        nds_ui_h "Install backup package"
        nds_ui_b "Copy this zip off the machine before you reboot."
        nds_ui_b "It includes your NDS configuration, install logs, and encryption keys (if any)."
        nds_ui_b ""
        nds_ui_i "$NDS_INSTALL_BUNDLE"
        nds_ui_b ""
        _nds_install_bundle_remote_copy_hint "$NDS_INSTALL_BUNDLE"

        if [[ "$(nds_config_get "disk" "ENCRYPTION")" == "true" ]]; then
            nds_ui_b ""
            _nds_ui_colored 35 "Encryption was enabled — saving this zip is important."
            _nds_ui_colored 35 "Without the LUKS key inside it, the installed system will not boot."
            nds_ui_b ""
            nds_askUserToProceed "I will back up the install package before rebooting" || return 1
            nds_ui_b ""
            nds_ui_b "Reboot manually once the package is safe offline: sudo reboot"
            return 0
        fi

        nds_ui_b ""
        nds_askUserToProceed "I have copied the package (or do not need it)" || return 1
        nds_ui_b ""
        nds_ui_b "Reboot when ready: sudo reboot"
        nds_askUserToProceed "Reboot now?" && reboot
        return 0
    fi

    # Bundle could not be created — installation still succeeded.
    if [[ "$bundle_ok" -ne 0 ]]; then
        warn "Install backup package could not be created, but installation succeeded."
    fi
    nds_ui_b ""
    nds_ui_b "Reboot when ready: sudo reboot"
    nds_askUserToProceed "Reboot now?" && reboot
    return 0
}

# End-of-install backup bundle and optional reboot.
nds_install_finish() {
    nds_install_bundle_finish || return 1
    return 0
}

# Legacy names (call sites / exports).
nds_secrets_create_bundle() { nds_install_bundle_create "$@"; }
nds_secrets_finish_install() { nds_install_bundle_finish "$@"; }
