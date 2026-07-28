#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install bundle paths
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-07-06
# ==================================================================================================

nds_install_ssh_user() {
    local user="${SUDO_USER:-nixos}"
    [[ "$user" == root ]] && user=nixos
    printf '%s' "$user"
}

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

nds_install_bundle_path() {
    local user
    user=$(nds_install_ssh_user)
    printf '/home/%s/nds_bundle.zip' "$user"
}

nds_install_bundle_local_name() {
    local hostname stamp
    _nixinstall_gather_context
    hostname="${NDS_CTX_HOSTNAME:-nixos}"
    printf -v stamp '%(%Y%m%d_%H%M%S)T' -1
    printf 'nds_install_backup_%s_%s.zip' "$stamp" "$hostname"
}
