#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key management
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-06
# Description:   Session SSH key paths, import, generate, load, target install (no config store)
# ==================================================================================================

declare -ga NDS_GIT_AUTH_REGISTER_URLS=()
declare -g NDS_GIT_QR_PREINSTALLED=false

# Description: Active private git SSH key path for this NDS session (persists under /root/.ssh).
# Returns:
# - <String> Key file path (stdout)
nds_git_session_key_path() {
    local slug base

    if [[ -n "${NDS_GIT_SESSION_KEY_PATH:-}" ]]; then
        printf '%s\n' "$NDS_GIT_SESSION_KEY_PATH"
        return 0
    fi
    slug="$(nds_git_owner_slug)"
    if [[ "$slug" != "unknown" ]]; then
        base="$(nds_git_secrets_basename)"
        printf '/root/.ssh/%s\n' "$base"
    else
        printf '/root/.ssh/id_ed25519\n'
    fi
}

# Description: Basename for owner-scoped git SSH key files (e.g. git-codeanthem-key).
# Returns:
# - <String> basename without directory (stdout)
nds_git_secrets_basename() {
    printf 'git-%s-key\n' "$(nds_git_owner_slug)"
}

# Description: Target install path relative to mount root.
# Returns:
# - <String> e.g. etc/nixos/secrets/git-codeanthem-key (stdout)
nds_git_target_key_rel() {
    printf 'etc/nixos/secrets/%s\n' "$(nds_git_secrets_basename)"
}

# Description: Absolute path on installed system.
# Returns:
# - <String> e.g. /etc/nixos/secrets/git-codeanthem-key (stdout)
nds_git_target_key_abs() {
    printf '/%s\n' "$(nds_git_target_key_rel)"
}

# Description: Public key path for the session git SSH key.
# Returns:
# - <String> .pub path (stdout)
nds_git_session_pubkey_path() {
    local key
    key="$(nds_git_session_key_path)"
    printf '%s\n' "${key}.pub"
}

# Description: SSH key title / ssh-keygen comment (owner + flake host when known).
# Returns:
# - <String> e.g. nds-codeanthem-control-toolkit
nds_git_deploy_key_title() {
    local name="" slug=""

    if declare -f nds_configurator_config_get &>/dev/null; then
        name="$(nds_configurator_config_get FLAKE_HOST 2>/dev/null || true)"
    fi
    [[ -z "$name" ]] && name="$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)"
    [[ -z "$name" ]] && name="$(nds_cfg_get NETWORK_HOSTNAME 2>/dev/null || true)"
    [[ -z "$name" ]] && name="$(hostname -s 2>/dev/null || echo live)"
    slug="$(nds_git_owner_slug)"
    if [[ "$slug" != "unknown" ]]; then
        printf 'nds-%s-%s' "$slug" "$name"
    else
        printf 'nds-%s' "$name"
    fi
}

# Description: Copy a private key into place with safe permissions and load into ssh-agent.
# Arguments:
# - src:  <String> Source private key file
# - dest: <String|optional> Destination path (default session key path)
# Returns:
# - <Bool> 0 on success
nds_git_key_import() {
    local src="$1" dest="${2:-$(nds_git_session_key_path)}"

    [[ -f "$src" ]] || { error "Deploy key not found: $src"; return 1; }
    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")"
    cp "$src" "$dest"
    chmod 600 "$dest"
    nds_git_key_load "$dest"
}

# Description: Load a private key into ssh-agent (starts agent if needed).
# Arguments:
# - key_path: <String|optional> Private key path
# Returns:
# - <Bool> 0 on success
nds_git_key_load() {
    local key_path="${1:-$(nds_git_session_key_path)}"

    [[ -f "$key_path" ]] || return 1
    if ! ssh-add -l &>/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    fi
    ssh-add "$key_path" >/dev/null 2>&1
}

# Description: Generate an ed25519 git SSH key pair (reuses existing file when present).
# Arguments:
# - dest:    <String|optional> Private key path
# - comment: <String|optional> Key comment (default nds-<owner>-<flake host>)
# Returns:
# - <Bool> 0 on success
nds_git_key_generate() {
    local dest="${1:-$(nds_git_session_key_path)}"
    local comment="${2:-$(nds_git_deploy_key_title)}"

    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")"
    if [[ -f "$dest" && "${NDS_GIT_KEY_FORCE_REGEN:-false}" != "true" ]]; then
        nds_git_key_load "$dest"
        log "Reusing git SSH key (${comment}) at ${dest}"
        return 0
    fi
    rm -f "$dest" "${dest}.pub"
    ssh-keygen -t ed25519 -N "" -f "$dest" -C "$comment" >/dev/null 2>&1 || {
        error "ssh-keygen failed"
        return 1
    }
    chmod 600 "$dest"
    nds_git_key_load "$dest"
    log "Git SSH key generated (${comment})"
}

# Description: Resolve qrencode command prefix (host binary or nix shell).
# Sets nameref array to command prefix.
nds_git_qr_cmd() {
    local -n _out=$1
    if command -v qrencode &>/dev/null; then
        _out=(qrencode)
        return 0
    fi
    if command -v nix &>/dev/null; then
        _out=(nix --extra-experimental-features "nix-command flakes" shell nixpkgs#qrencode -c qrencode)
        return 0
    fi
    _out=()
    return 1
}

# Description: Download qrencode once per session (after user chose QR display).
# Returns:
# - 0 when qrencode is available or already prefetched
nds_git_qr_preinstall() {
    local -a qr_cmd=()

    [[ "${NDS_GIT_QR_PREINSTALLED}" == "true" ]] && return 0
    if command -v qrencode &>/dev/null; then
        NDS_GIT_QR_PREINSTALLED=true
        return 0
    fi
    nds_git_qr_cmd qr_cmd || return 1
    info "Installing qrencode for QR display (one-time download)..."
    if "${qr_cmd[@]}" --version >/dev/null 2>&1; then
        NDS_GIT_QR_PREINSTALLED=true
        success "qrencode ready"
        return 0
    fi
    warn "Could not install qrencode — use printed copy instead"
    return 1
}

# Description: Print the public deploy key to the console.
# Arguments:
# - pub_path: <String|optional> Public key path
# Returns:
# - <Bool> 0 when key exists
nds_git_key_show_pubkey() {
    local pub_path="${1:-$(nds_git_session_pubkey_path)}"
    [[ -f "$pub_path" ]] || return 1
    nds_ui_b ""
    nds_ui_h "Deploy public key ($(nds_git_deploy_key_title)):"
    nds_ui_b ""
    console "$(cat "$pub_path")"
    nds_ui_b ""
    return 0
}

# Description: Run qrencode with a terminal output format (internal).
_nds_git_qr_try_format() {
    local fmt="$1" payload="$2"
    shift 2
    local -a qr_cmd=("$@")
    "${qr_cmd[@]}" -t "$fmt" <<< "$payload" 2>/dev/null
}

# Description: Render one QR code for arbitrary text.
# Arguments:
# - label:   <String> Heading above the QR
# - payload: <String> Text to encode
# Returns:
# - 0 when rendered or qrencode missing (non-fatal)
nds_git_key_show_qr_payload() {
    local label="$1" payload="$2"
    local fmt
    local -a qr_cmd=()

    [[ -n "$payload" ]] || return 0
    if ! nds_git_qr_cmd qr_cmd; then
        nds_ui_i "qrencode not available — copy the printed text instead"
        return 0
    fi

    nds_ui_b ""
    nds_ui_h "$label"
    nds_ui_b ""

    for fmt in ANSIUTF8 ANSI UTF8; do
        if _nds_git_qr_try_format "$fmt" "$payload" "${qr_cmd[@]}"; then
            nds_ui_b ""
            return 0
        fi
    done

    debug "qrencode failed for all terminal formats (TERM=${TERM:-unset})"
    nds_ui_i "QR render failed for: ${label}"
    nds_ui_b ""
    return 0
}

# Description: Show deploy-key page URL QR(s) and public-key QR.
# Arguments:
# - pub_path: <String|optional> Public key path
nds_git_key_show_qr_bundle() {
    local pub_path="${1:-$(nds_git_session_pubkey_path)}"
    local pub url

    [[ -f "$pub_path" ]] || return 1
    pub="$(tr -d '\n' < "$pub_path")"

    nds_ui_b ""
    nds_ui_i "Scan with your phone — open the page URL in a browser, paste the public key."
    nds_ui_b ""

    for url in "${NDS_GIT_AUTH_REGISTER_URLS[@]}"; do
        [[ "$url" == http* ]] || continue
        nds_git_key_show_qr_payload "Deploy-keys page" "$url"
        nds_ui_i "$url"
        nds_ui_b ""
    done

    nds_git_key_show_qr_payload "Public key (paste on deploy-keys page)" "$pub"
    return 0
}

# Description: Show deploy public key as printed text and optionally QR bundle.
# Arguments:
# - display:  <String> "copy" or "qr"
# - pub_path: <String|optional> Public key path
nds_git_key_show_deploy_pubkey() {
    local display="${1:-copy}"
    local pub_path="${2:-$(nds_git_session_pubkey_path)}"

    nds_git_key_show_pubkey "$pub_path" || return 1
    if [[ "$display" == "qr" ]]; then
        nds_git_key_show_qr_bundle "$pub_path" || true
    fi
    return 0
}

# Description: Install session git SSH private key onto the target root under /mnt.
# Not included in the install backup zip.
# Arguments:
# - key_path:   <String|optional> Source private key
# - mount_root: <String|optional> Target mount (default /mnt)
# - dest_rel:   <String|optional> Path relative to mount (default etc/nixos/secrets/git-<owner>-key)
# Returns:
# - <Bool> 0 on success or when skipped (no key / no mount)
nds_git_install_deploy_key_to_target() {
    local key_path="${1:-$(nds_git_session_key_path)}"
    local mount_root="${2:-/mnt}"
    local dest_rel="${3:-$(nds_git_target_key_rel)}"
    local dest_dir dest

    [[ -f "$key_path" ]] || {
        debug "No session git SSH key — skip target install"
        return 0
    }
    [[ -d "$mount_root" ]] || {
        debug "Target mount missing — skip git SSH key install"
        return 0
    }

    dest="${mount_root}/${dest_rel}"
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"
    install -m 600 -o root -g root "$key_path" "$dest"
    export NDS_GIT_TARGET_KEY_REL="$dest_rel"
    export NDS_GIT_TARGET_KEY_ABS="/${dest_rel}"
    log "Git SSH key installed on target: ${NDS_GIT_TARGET_KEY_ABS} (mode 600, excluded from backup zip)"
    nds_install_log "git: SSH key -> ${NDS_GIT_TARGET_KEY_ABS} (persists for flake/git fetches after reboot)"
    return 0
}

# Description: Load persisted session key from /root/.ssh when NDS restarts on the live ISO.
# Returns:
# - <Bool> 0 when an existing session key was loaded
nds_git_auth_try_session_key() {
    local dest

    dest="$(nds_git_session_key_path)"
    [[ -f "$dest" ]] || return 1
    nds_git_key_load "$dest" || return 1
    debug "Reused persisted git SSH key: ${dest}"
    return 0
}

# Description: Try loading a pre-set NDS_DEPLOY_KEY_PATH before interactive auth.
# Returns:
# - <Bool> 0 when key was imported and loaded
nds_git_auth_try_deploy_key_path() {
    local path="${NDS_DEPLOY_KEY_PATH:-}"
    local dest
    [[ -n "$path" && -f "$path" ]] || return 1
    dest="$(nds_git_session_key_path)"
    if [[ "$path" == "$dest" ]]; then
        nds_git_key_load "$dest" || return 1
    else
        nds_git_key_import "$path" "$dest" || return 1
    fi
    debug "Loaded deploy key from NDS_DEPLOY_KEY_PATH"
    return 0
}
