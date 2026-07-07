#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard manual registration menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Resolve QR vs printed copy (env or one-time prompt).
# Returns:
# - <String> qr or copy (stdout)
nds_git_wizard_resolve_key_display() {
    local from_env="${NDS_GIT_SSH_KEY_DISPLAY:-${NDS_GIT_DEPLOY_KEY_DISPLAY:-}}"
    case "${from_env,,}" in
        qr) printf 'qr\n'; return 0 ;;
        copy) printf 'copy\n'; return 0 ;;
    esac
    if nds_env_is_true "${NDS_GIT_SSH_KEY_USE_QR:-${NDS_GIT_DEPLOY_KEY_USE_QR:-false}}"; then
        printf 'qr\n'
        return 0
    fi
    if [[ "${NDS_GIT_SSH_KEY_USE_QR:-${NDS_GIT_DEPLOY_KEY_USE_QR:-}}" == "false" ]]; then
        printf 'copy\n'
        return 0
    fi
    nds_cfg_ask_toggle GIT_SSH_KEY_USE_QR "Generate QR codes for URL and public key?" false
    if nds_cfg_true GIT_SSH_KEY_USE_QR; then
        printf 'qr\n'
    else
        printf 'copy\n'
    fi
}

# Description: Show public key and optional QR bundle for manual registration.
# Arguments:
# - display: <String> qr or copy
# Returns:
# - <Bool> 0 on success
nds_git_wizard_show_manual_key() {
    local display="${1:-copy}"
    local pub_path register_url

    pub_path="$(nds_git_session_pubkey_path)"
    [[ -f "$pub_path" ]] || return 1

    nds_ui_b ""
    nds_ui_h "SSH public key ($(nds_git_ssh_key_title)):"
    nds_ui_b ""
    console "$(cat "$pub_path")"
    nds_ui_b ""

    if [[ "$display" == "qr" ]]; then
        if nds_git_qr_preinstall; then
            for register_url in "${NDS_GIT_AUTH_REGISTER_URLS[@]}"; do
                [[ "$register_url" == http* ]] || continue
                nds_git_qr_show_manual_bundle "$register_url" "$pub_path" || true
            done
        else
            warn "QR unavailable — use printed copy above"
        fi
    fi
    return 0
}

# Description: Wait until user confirms manual SSH key registration.
# Returns:
# - <Bool> 0 when user confirms
nds_git_wizard_confirm_manual_register() {
    nds_ui_b "Register the public key on your git host account — read-only is enough."
    nds_ui_b ""
    nds_ui_i "GitHub: leave \"Allow write access\" unchecked at github.com/settings/ssh/new"
    nds_ui_i "Title: $(nds_git_ssh_key_title)"
    nds_ui_b ""
    nds_askUserToProceed "Added this SSH key to your account?" || return 1
    return 0
}

# Description: Manual registration path — generate if needed, optional QR, confirm.
# Returns:
# - <Bool> 0 on success
nds_git_wizard_menu_manual() {
    local display

    if [[ ! -f "$(nds_git_session_pubkey_path)" ]]; then
        nds_git_key_generate "$(nds_git_session_key_path)" || return 1
    fi

    display="$(nds_git_wizard_resolve_key_display)" || return 1
    nds_git_wizard_show_manual_key "$display" || return 1
    nds_git_wizard_confirm_manual_register || return 1
    return 0
}
