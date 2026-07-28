#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install bundle archive creation
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-07-06
# ==================================================================================================

nds_install_bundle_create() {
    local staging bundle_path user item secret_files=()
    local install_log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local diag_log="${NDS_INSTALL_DIAG_LOG:-/tmp/nds_install_diag.log}"
    local session_log="${NDS_INSTALL_LOG:-/tmp/nds_session.log}"

    if [[ -n "${NDS_INSTALL_BUNDLE:-}" && -f "$NDS_INSTALL_BUNDLE" ]]; then
        return 0
    fi

    _nixinstall_gather_context

    user=$(nds_install_ssh_user)
    bundle_path=$(nds_install_bundle_path)
    staging=$(mktemp -d "${TMPDIR:-/tmp}/nds-bundle-staging.XXXXXX") || return 1

    mkdir -p "${staging}/config" "${staging}/secrets" "${staging}/logs"

    nds_configurator_config_export_script > "${staging}/nds-config.env"

    if [[ -f "${NDS_RUNTIME_DIR:-}/config/configuration.nix" ]]; then
        cp "${NDS_RUNTIME_DIR}/config/configuration.nix" "${staging}/config/"
    fi
    if [[ -f "${NDS_RUNTIME_DIR:-}/config/hardware-configuration.nix" ]]; then
        cp "${NDS_RUNTIME_DIR}/config/hardware-configuration.nix" "${staging}/config/"
    fi
    if [[ -f "${NDS_RUNTIME_DIR:-}/config/facter.json" ]]; then
        cp "${NDS_RUNTIME_DIR}/config/facter.json" "${staging}/config/"
    fi

    [[ -f "$install_log" ]] && cp "$install_log" "${staging}/logs/install.log"
    [[ -f "$diag_log" ]] && cp "$diag_log" "${staging}/logs/diag.log"
    [[ -f "$session_log" ]] && cp "$session_log" "${staging}/logs/session.log"

    mapfile -t secret_files < <(nds_secrets_list_runtime)
    for item in "${secret_files[@]}"; do
        [[ -f "$item" ]] && cp "$item" "${staging}/secrets/"
    done

    _nds_install_bundle_quickstart "${staging}/NDS_QUICK_START.md"

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

    chown "$user" "$bundle_path" 2>/dev/null || true
    chmod 600 "$bundle_path"

    export NDS_INSTALL_BUNDLE="$bundle_path"
    export NDS_SECRETS_BUNDLE="$bundle_path"
    nds_install_log "install backup bundle: $bundle_path"
    return 0
}

nds_secrets_create_bundle() { nds_install_bundle_create "$@"; }
