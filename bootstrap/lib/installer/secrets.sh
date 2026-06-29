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
# Usage: nds_secrets_create_bundle
nds_secrets_create_bundle() {
    local secret_files=()
    local hostname stamp bundle item

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

    section_header "Backup encryption keys"
    nds_ui_b "Copy this file off the machine before continuing."
    nds_ui_b "It lives in /tmp and is removed on reboot."
    nds_ui_b ""
    nds_ui_h "$bundle"
    nds_ui_b ""
    nds_ui_b "Install log (verbose output): ${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    nds_ui_b ""
    nds_askUserToProceed "I have backed up the secrets bundle" || return 1
    return 0
}

# Offer to copy runtime secrets to a user path (USB stick, etc.).
# Usage: nds_secrets_offer_backup
nds_secrets_offer_backup() {
    local secret_files=()
    local path item dest

    if [[ -n "${NDS_SECRETS_BUNDLE:-}" && -f "$NDS_SECRETS_BUNDLE" ]]; then
        section_header "Secrets backup reminder"
        nds_ui_b "Secrets bundle (copy before reboot):"
        nds_ui_h "$NDS_SECRETS_BUNDLE"
        nds_ui_b ""
        return 0
    fi

    mapfile -t secret_files < <(nds_secrets_list_runtime)

    if [[ ${#secret_files[@]} -eq 0 ]]; then
        return 0
    fi

    section_header "Secrets backup required"
    nds_ui_b "Back up these files before reboot:"
    for item in "${secret_files[@]}"; do
        nds_ui_i "$item"
    done
    nds_ui_b ""
    nds_ui_b "Store offline (password manager, encrypted USB, Cryptomator vault)."
    nds_ui_b ""

    if [[ ! -t 0 ]] || [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
        warn "Copy secrets manually from the paths above"
        return 0
    fi

    read -rp "Copy secrets to directory (blank to skip): " path < /dev/tty
    if [[ -z "$path" ]]; then
        return 0
    fi

    mkdir -p "$path" || {
        error "Cannot create $path"
        return 1
    }

    for item in "${secret_files[@]}"; do
        dest="$path/$(basename "$item")"
        cp "$item" "$dest" && chmod 600 "$dest"
    done

    success "Secrets copied to $path"
    nds_install_log "secrets backed up to $path"
    return 0
}
