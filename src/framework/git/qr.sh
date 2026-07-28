#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth QR display helpers (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

declare -g NDS_GIT_QR_PREINSTALLED=false

# Description: Resolve qrencode command prefix (host binary or nix shell).
# Arguments:
# - out: <Nameref> Command prefix array
# Returns:
# - <Bool> 0 when qrencode is available
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

# Description: Download qrencode once per session.
# Returns:
# - <Bool> 0 when qrencode is available
nds_git_qr_preinstall() {
    local -a qr_cmd=()

    [[ "${NDS_GIT_QR_PREINSTALLED}" == "true" ]] && return 0
    if command -v qrencode &>/dev/null; then
        NDS_GIT_QR_PREINSTALLED=true
        return 0
    fi
    nds_git_qr_cmd qr_cmd || return 1
    if "${qr_cmd[@]}" --version >/dev/null 2>&1; then
        NDS_GIT_QR_PREINSTALLED=true
        return 0
    fi
    return 1
}

# Description: Run qrencode with a terminal output format.
_nds_git_qr_try_format() {
    local fmt="$1" payload="$2"
    shift 2
    local -a qr_cmd=("$@")
    "${qr_cmd[@]}" -t "$fmt" <<< "$payload" 2>/dev/null
}

# Description: Render one QR code for arbitrary text (non-fatal when qrencode missing).
# Arguments:
# - label:   <String> Heading above the QR
# - payload: <String> Text to encode
# Returns:
# - <Bool> 0 when rendered or skipped gracefully
nds_git_qr_show_payload() {
    local label="$1" payload="$2"
    local fmt
    local -a qr_cmd=()

    [[ -n "$payload" ]] || return 0
    if ! nds_git_qr_cmd qr_cmd; then
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
    return 0
}

# Description: Show account SSH registration URL QR and public-key QR.
# Arguments:
# - register_url: <String> HTTPS registration page
# - pub_path:     <String|optional> Public key path
# Returns:
# - <Bool> 0 when key exists
nds_git_qr_show_manual_bundle() {
    local register_url="$1"
    local pub_path="${2:-$(nds_git_session_pubkey_path)}"
    local pub

    [[ -f "$pub_path" ]] || return 1
    pub="$(tr -d '\n' < "$pub_path")"

    nds_git_qr_show_payload "SSH key registration page" "$register_url"
    nds_ui_i "$register_url"
    nds_ui_b ""
    nds_git_qr_show_payload "Public key (paste on registration page)" "$pub"
    return 0
}
