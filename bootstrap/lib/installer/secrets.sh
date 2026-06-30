#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install-time secrets backup
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Collect and optionally copy LUKS keys / runtime secrets before reboot
# ==================================================================================================

# List secret files produced during this install session.
# Usage: nds_secrets_list_runtime
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

# Pack runtime secrets into /tmp (survives until reboot; not removed with runtime purge).
# Silent — no prompts. Sets NDS_SECRETS_BUNDLE when files exist.
# Usage: nds_secrets_create_bundle
nds_secrets_create_bundle() {
    local secret_files=()
    local hostname stamp bundle

    if [[ -n "${NDS_SECRETS_BUNDLE:-}" && -f "$NDS_SECRETS_BUNDLE" ]]; then
        return 0
    fi

    mapfile -t secret_files < <(nds_secrets_list_runtime)
    [[ ${#secret_files[@]} -eq 0 ]] && return 0

    hostname=$(nds_config_get "network" "HOSTNAME" 2>/dev/null || true)
    hostname="${hostname:-nixos}"
    printf -v stamp '%(%Y%m%d_%H%M%S)T' -1

    if command -v zip &>/dev/null; then
        bundle="/tmp/nds-secrets-${hostname}-${stamp}.zip"
        zip -j -q "$bundle" "${secret_files[@]}" || {
            error "Failed to create secrets bundle: $bundle"
            return 1
        }
    else
        bundle="/tmp/nds-secrets-${hostname}-${stamp}.tar.gz"
        tar czf "$bundle" "${secret_files[@]}" || {
            error "Failed to create secrets bundle: $bundle"
            return 1
        }
    fi
    chmod 600 "$bundle"
    export NDS_SECRETS_BUNDLE="$bundle"
    nds_install_log "secrets bundle: $bundle"
    return 0
}

# Build copy hints for the PC that SSH'd into this host (run on your PC).
_nds_secrets_remote_copy_hint() {
    local bundle="$1"
    local ssh_user host remote_path published bundle_name

    ssh_user="${SUDO_USER:-nixos}"
    [[ "$ssh_user" == root ]] && ssh_user=nixos

    remote_path="$bundle"
    bundle_name=$(basename "$bundle")
    if [[ -d "/home/${ssh_user}" ]]; then
        published="/home/${ssh_user}/${bundle_name}"
        cp "$bundle" "$published"
        chown "${ssh_user}:${ssh_user}" "$published"
        chmod 600 "$published"
        remote_path="$published"
    fi

    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        read -r _ _ host _ <<< "$SSH_CONNECTION"
    elif command -v ip &>/dev/null; then
        host=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") print $(i+1); exit}')
    fi
    host="${host:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
    [[ -z "$host" ]] && return 0

    nds_ui_b "From your PC (open a second terminal), run one of:"
    nds_ui_i "scp ${ssh_user}@${host}:${remote_path} ."
    nds_ui_i "ssh ${ssh_user}@${host} \"cat ${remote_path}\" > ${bundle_name}"
    nds_ui_b "(scp and ssh work on Linux, macOS, and Windows 10+ OpenSSH client)"
    nds_ui_b ""
}

# Post-install screen: show bundle path, acknowledge backup before manual reboot.
# Usage: nds_secrets_finish_install
nds_secrets_finish_install() {
    nds_secrets_create_bundle || return 1

    if [[ -z "${NDS_SECRETS_BUNDLE:-}" || ! -f "$NDS_SECRETS_BUNDLE" ]]; then
        return 0
    fi

    section_header "Backup encryption keys"
    nds_ui_b "Copy this bundle off the machine before you reboot."
    nds_ui_b "It lives in /tmp and is removed on reboot."
    nds_ui_b ""
    nds_ui_i "$NDS_SECRETS_BUNDLE"
    nds_ui_b ""
    _nds_secrets_remote_copy_hint "$NDS_SECRETS_BUNDLE"
    nds_ui_b "Install log (verbose output): ${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    nds_ui_b ""
    nds_askUserToProceed "I will back up these keys before rebooting" || return 1
    nds_ui_b ""
    nds_ui_b "Installation finished. Reboot manually when your keys are safe."
    return 0
}

# End-of-install: secrets acknowledgment when encrypted; optional reboot otherwise.
# Usage: nds_install_finish
nds_install_finish() {
    if [[ "$(nds_config_get "disk" "ENCRYPTION")" == "true" ]]; then
        nds_secrets_finish_install || return 1
        return 0
    fi

    nds_ui_b "Reboot when ready: sudo reboot"
    nds_askUserToProceed "Reboot now?" && reboot
    return 0
}
