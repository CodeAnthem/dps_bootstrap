#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git deploy key management
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-06
# Description:   Session deploy key paths, import, generate, load, target install (no config store)
# ==================================================================================================

# Description: Active private deploy key path for this NDS session.
# Returns:
# - <String> Key file path (stdout)
nds_git_session_key_path() {
    printf '%s\n' "${NDS_GIT_SESSION_KEY_PATH:-/root/.ssh/id_ed25519}"
}

# Description: Public key path for the session deploy key.
# Returns:
# - <String> .pub path (stdout)
nds_git_session_pubkey_path() {
    local key
    key="$(nds_git_session_key_path)"
    printf '%s\n' "${key}.pub"
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

# Description: Generate a new ed25519 deploy key pair.
# Arguments:
# - dest:    <String|optional> Private key path
# - comment: <String|optional> Key comment
# Returns:
# - <Bool> 0 on success
nds_git_key_generate() {
    local dest="${1:-$(nds_git_session_key_path)}"
    local comment="${2:-nds-deploy-$(hostname -s 2>/dev/null || echo live)}"

    mkdir -p "$(dirname "$dest")"
    chmod 700 "$(dirname "$dest")"
    rm -f "$dest" "${dest}.pub"
    ssh-keygen -t ed25519 -N "" -f "$dest" -C "$comment" >/dev/null 2>&1 || {
        error "ssh-keygen failed"
        return 1
    }
    chmod 600 "$dest"
    nds_git_key_load "$dest"
}

declare -g NDS_GIT_QR_PREINSTALLED=false

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

# Description: Download qrencode once per session so later QR renders are instant.
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
    info "Prefetching qrencode for QR display (one-time download)..."
    if "${qr_cmd[@]}" --version >/dev/null 2>&1; then
        NDS_GIT_QR_PREINSTALLED=true
        success "qrencode ready"
        return 0
    fi
    warn "Could not prefetch qrencode — QR may be slow or unavailable"
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
    nds_ui_h "Deploy public key:"
    nds_ui_b ""
    console "$(cat "$pub_path")"
    nds_ui_b ""
    return 0
}

# Description: Run qrencode with a terminal output format (internal).
_nds_git_qr_try_format() {
    local fmt="$1" pub="$2"
    shift 2
    local -a qr_cmd=("$@")
    "${qr_cmd[@]}" -t "$fmt" <<< "$pub" 2>/dev/null
}

# Description: Show public key as a terminal QR code when qrencode is available.
# Arguments:
# - pub_path: <String|optional> Public key path
# Returns:
# - <Bool> 0 when QR was displayed or key missing (non-fatal skip)
nds_git_key_show_qr() {
    local pub_path="${1:-$(nds_git_session_pubkey_path)}"
    local pub fmt
    local -a qr_cmd=()

    [[ -f "$pub_path" ]] || return 1
    pub="$(tr -d '\n' < "$pub_path")"

    if ! nds_git_qr_cmd qr_cmd; then
        nds_ui_i "qrencode not available — copy the printed public key instead"
        return 0
    fi

    nds_ui_b ""
    nds_ui_h "Scan to copy the deploy public key:"
    nds_ui_i "(Phone camera or any QR app — paste into GitHub deploy-keys page in a browser)"
    nds_ui_b ""

    for fmt in ANSIUTF8 ANSI UTF8; do
        if _nds_git_qr_try_format "$fmt" "$pub" "${qr_cmd[@]}"; then
            nds_ui_b ""
            return 0
        fi
    done

    debug "qrencode failed for all terminal formats (TERM=${TERM:-unset})"
    nds_ui_i "QR render failed — use the printed public key above"
    nds_ui_i "(VM console may not support QR — copy the key text or use gh to register)"
    nds_ui_b ""
    return 0
}

# Description: Show deploy public key as printed text and optionally QR.
# Arguments:
# - display:  <String> "copy" or "qr"
# - pub_path: <String|optional> Public key path
nds_git_key_show_deploy_pubkey() {
    local display="${1:-copy}"
    local pub_path="${2:-$(nds_git_session_pubkey_path)}"

    nds_git_key_show_pubkey "$pub_path" || return 1
    if [[ "$display" == "qr" ]]; then
        nds_git_key_show_qr "$pub_path" || true
    fi
    return 0
}

# Description: Install session deploy private key onto the target root under /mnt.
# Not included in the install backup zip.
# Arguments:
# - key_path:   <String|optional> Source private key
# - mount_root: <String|optional> Target mount (default /mnt)
# - dest_rel:   <String|optional> Path relative to mount (default etc/nixos/secrets/git-deploy-key)
# Returns:
# - <Bool> 0 on success or when skipped (no key / no mount)
nds_git_install_deploy_key_to_target() {
    local key_path="${1:-$(nds_git_session_key_path)}"
    local mount_root="${2:-/mnt}"
    local dest_rel="${3:-etc/nixos/secrets/git-deploy-key}"
    local dest_dir dest

    [[ -f "$key_path" ]] || {
        debug "No session deploy key — skip target install"
        return 0
    }
    [[ -d "$mount_root" ]] || {
        debug "Target mount missing — skip deploy key install"
        return 0
    }

    dest="${mount_root}/${dest_rel}"
    dest_dir="$(dirname "$dest")"
    mkdir -p "$dest_dir"
    install -m 600 -o root -g root "$key_path" "$dest"
    log "Git deploy key installed on target: /${dest_rel}"
    nds_install_log "git: deploy key -> /${dest_rel} (excluded from backup zip)"
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
