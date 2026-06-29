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

# Offer to copy runtime secrets to a user path (USB stick, etc.).
# Usage: nds_secrets_offer_backup
nds_secrets_offer_backup() {
    local secret_files=()
    local path item dest

    mapfile -t secret_files < <(nds_secrets_list_runtime)

    if [[ ${#secret_files[@]} -eq 0 ]]; then
        return 0
    fi

    section_header "Secrets backup required"
    console ""
    console "Back up these files before reboot:"
    for item in "${secret_files[@]}"; do
        console "  • $item"
    done
    console ""
    console "Store offline (password manager, encrypted USB, Cryptomator vault)."
    console ""

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
