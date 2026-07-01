#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install backup bundle
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-06-30
# Description:   End-of-install zip (config export, generated configs, logs, keys)
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
    local install_log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local session_log="${NDS_INSTALL_LOG:-/tmp/nds_session.log}"

    if [[ -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        return 0
    fi

    user=$(nds_install_ssh_user)
    bundle_path=$(nds_install_bundle_path)
    staging=$(mktemp -d "${TMPDIR:-/tmp}/nds-bundle-staging.XXXXXX") || return 1

    mkdir -p "${staging}/config" "${staging}/secrets" "${staging}/logs"

    # Config export at the root so it is the first thing the user sees.
    nds_configurator_config_export_script > "${staging}/nds-config.env"

    if [[ -f "${NDS_RUNTIME_DIR:-}/config/configuration.nix" ]]; then
        cp "${NDS_RUNTIME_DIR}/config/configuration.nix" "${staging}/config/"
    fi
    if [[ -f "${NDS_RUNTIME_DIR:-}/config/hardware-configuration.nix" ]]; then
        cp "${NDS_RUNTIME_DIR}/config/hardware-configuration.nix" "${staging}/config/"
    fi

    # Two logs: verbose nix install output and everything else (session events).
    [[ -f "$install_log" ]] && cp "$install_log" "${staging}/logs/install.log"
    [[ -f "$session_log" ]] && cp "$session_log" "${staging}/logs/session.log"

    mapfile -t secret_files < <(nds_secrets_list_runtime)
    for item in "${secret_files[@]}"; do
        [[ -f "$item" ]] && cp "$item" "${staging}/secrets/"
    done

    cat > "${staging}/README.txt" <<EOF
NDS install backup package
Hostname: $(nds_config_get "network" "HOSTNAME" 2>/dev/null || echo unknown)
Created: $(date -Iseconds 2>/dev/null || date)

Contents:
  nds-config.env          — paste before a future NDS run
  config/*.nix            — generated NixOS configs (if present)
  secrets/                — credentials and unlock material:
    admin_password.txt      Admin user's initial password (save this!)
    luks_password.txt       LUKS passphrase (if password slot enabled)
    luks_key.bin            LUKS keyfile (if key slot enabled) — copy to USB
    initrd_ssh_host_ed25519_key[.pub]  initrd SSH host key (if remote unlock)
  logs/install.log        — verbose nix install output
  logs/session.log        — NDS session events (info/warnings/errors)

First login:
  Console:  log in as the admin user with admin_password.txt
  SSH:      ssh <admin_user>@<host>   (password login unless you set a key)
  Change the admin password after first login with: passwd
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

    nds_ui_b "Backup it from your local machine:"
    nds_ui_i "SCP:"
    nds_ui_i "  scp ${ssh_user}@${host}:${bundle_path} ."
    nds_ui_b ""
    nds_ui_i "SSH:"
    nds_ui_i "  ssh ${ssh_user}@${host} \"cat ${bundle_path}\" > ${bundle_name}"
    nds_ui_b ""
}

# Description: Print post-install login instructions for the admin user.
_nds_install_bundle_access_instructions() {
    local admin_user ssh_enable ssh_pw_auth ssh_port
    admin_user=$(nds_config_get "access" "ADMIN_USER")
    ssh_enable=$(nds_config_get "access" "SSH_ENABLE")
    ssh_pw_auth=$(nds_config_get "access" "SSH_PASSWORD_AUTH")
    ssh_port=$(nds_config_get "access" "SSH_PORT")

    nds_ui_b ""
    nds_ui_h "First login"
    nds_ui_i "Admin user: ${admin_user}"
    nds_ui_i "Admin password: in this zip at secrets/admin_password.txt"
    if [[ "$ssh_enable" == "true" ]]; then
        local host
        host=$(nds_install_bundle_host_ip)
        if [[ -n "$host" ]]; then
            nds_ui_i "SSH (from your local machine):"
            nds_ui_i "  ssh ${admin_user}@${host}$([[ "$ssh_port" != "22" ]] && printf ' -p %s' "$ssh_port")"
        else
            nds_ui_i "SSH: ssh ${admin_user}@<host-ip>"
        fi
        if [[ "$ssh_pw_auth" == "true" ]]; then
            nds_ui_i "Password login is enabled — use the password above."
        else
            nds_ui_i "Password login is OFF — use your configured SSH key."
        fi
    fi
    nds_ui_i "Console login also works with the admin user + password."
    _nds_ui_colored 33 "Change the admin password after first login: passwd"
}

# Description: Print post-install instructions for preparing the USB key and
# remote unlock, based on the chosen encryption model.
_nds_install_bundle_encryption_instructions() {
    local encryption use_password use_key key_device key_file remote_unlock
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    [[ "$encryption" == "true" ]] || return 0

    use_password=$(nds_config_get "disk" "ENCRYPTION_PASSWORD")
    use_key=$(nds_config_get "disk" "ENCRYPTION_KEY")
    key_device=$(nds_config_get "disk" "ENCRYPTION_KEY_BOOT_DEVICE")
    key_file=$(nds_config_get "disk" "ENCRYPTION_KEY_BOOT_FILE")
    remote_unlock=$(nds_config_get "disk" "ENCRYPTION_REMOTE_UNLOCK")

    if [[ "$use_key" == "true" ]]; then
        nds_ui_b ""
        nds_ui_h "Prepare your USB key (required to boot)"
        nds_ui_i "The LUKS key is in this zip at secrets/luks_key.bin."

        if [[ -z "$key_file" ]]; then
            nds_ui_i "Copy it to a USB stick as RAW bytes BEFORE rebooting:"
            nds_ui_i "  dd if=luks_key.bin of=<usb-device> bs=4096 count=1"
            nds_ui_i "Plug that USB in at every boot. Its device path must match:"
            nds_ui_i "  ENCRYPTION_KEY_BOOT_DEVICE = ${key_device}"
        else
            nds_ui_i "Copy it to a file on a USB stick BEFORE rebooting:"
            nds_ui_i "  mount <usb-device> /mnt/usb"
            nds_ui_i "  cp luks_key.bin /mnt/usb/${key_file}"
            nds_ui_i "  umount /mnt/usb"
            nds_ui_i "Plug that USB in at every boot. Its device path must match:"
            nds_ui_i "  ENCRYPTION_KEY_BOOT_DEVICE = ${key_device}"
        fi

        if [[ "$use_password" != "true" ]]; then
            nds_ui_b ""
            _nds_ui_colored 31 "WARNING: key-only mode (no password)."
            _nds_ui_colored 31 "If this USB is lost, stolen, or corrupted, the system CANNOT boot."
            _nds_ui_colored 31 "There is no fallback. Consider re-installing with a password too."
        fi
    fi

    if [[ "$remote_unlock" == "true" ]]; then
        nds_ui_b ""
        nds_ui_h "Remote unlock (initrd SSH)"
        nds_ui_i "Initrd SSH will be available at boot on port 22."
        local net_mode
        net_mode=$(nds_config_get "disk" "ENCRYPTION_REMOTE_NETWORK")
        if [[ "$net_mode" == "dhcp" ]]; then
            nds_ui_i "IP is assigned by DHCP — check your router/DHCP logs for the address."
        else
            nds_ui_i "Static IP from your network settings."
        fi
        nds_ui_i "Unlock with:  ssh -t root@<ip> 'systemctl default'"
        nds_ui_i "Authorized key: the public key you provided during configuration."
        nds_ui_i "Initrd SSH host key is in this zip at secrets/initrd_ssh_host_ed25519_key"
    fi
}

# Post-install screen: success banner, bundle path, copy commands, reboot prompt.
nds_install_bundle_finish() {
    local bundle_ok=1
    nds_install_bundle_create || bundle_ok=0

    if [[ "$bundle_ok" -ne 0 && -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        nds_ui_b ""
        nds_ui_h "Save the restore package for future use"
        nds_ui_b "Copy this zip off the machine before you reboot."
        nds_ui_b "It includes your NDS configuration, install logs, and unlock material (if encrypted)."
        nds_ui_b ""

        if [[ "$(nds_config_get "disk" "ENCRYPTION")" == "true" ]]; then
            _nds_ui_colored 35 "Encryption was enabled — saving this zip is important."
            _nds_ui_colored 35 "Keep it somewhere safe and offline; it contains your unlock secrets."
            nds_ui_b ""
        fi

        _nds_install_bundle_encryption_instructions

        _nds_install_bundle_access_instructions

        nds_ui_b ""
        _nds_install_bundle_remote_copy_hint "$NDS_INSTALL_BUNDLE"
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
