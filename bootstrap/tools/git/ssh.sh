#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH environment
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# Description:   Non-interactive SSH env for git and nix fetches
# ==================================================================================================

# Description: Path to generated OpenSSH config for this NDS session.
nds_git_ssh_config_path() {
    printf '%s/ssh/config\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Rewrite session SSH config with every registered private key.
nds_git_ssh_config_refresh() {
    local cfg key_path

    cfg="$(nds_git_ssh_config_path)"
    mkdir -p "$(dirname "$cfg")"
    {
        printf 'Host github.com *.github.com\n'
        printf '  HostName github.com\n'
        printf '  StrictHostKeyChecking accept-new\n'
        while IFS= read -r key_path; do
            [[ -f "$key_path" ]] && printf '  IdentityFile %s\n' "$key_path"
        done < <(nds_git_keys_list 2>/dev/null || true)
        printf '  IdentitiesOnly yes\n'
    } >"$cfg"
    chmod 600 "$cfg"
    nds_git_ssh_wrapper_refresh || true
}

# Description: Best private key path for a git remote URL (deploy key per repo first).
# Arguments:
# - url: <String> Git remote URL
# Returns:
# - <String> Private key path (stdout), non-zero when none found
_nds_git_identity_for_url() {
    local url="$1" ssh_url parsed host owner repo key base reg_key

    ssh_url=$(_nds_git_ssh_url "$url")
    parsed=$(_nds_git_parse "$ssh_url") || return 1
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    key="$(nds_git_deploy_key_path "$owner" "$repo" 2>/dev/null || true)"
    [[ -f "$key" ]] && {
        printf '%s\n' "$key"
        return 0
    }
    base="$(nds_git_deploy_key_basename "$owner" "$repo" 2>/dev/null || true)"
    if [[ -n "$base" ]]; then
        while IFS= read -r reg_key; do
            [[ -f "$reg_key" && "$(basename "$reg_key")" == "$base" ]] && {
                printf '%s\n' "$reg_key"
                return 0
            }
        done < <(nds_git_keys_list 2>/dev/null || true)
    fi
    key="$(nds_git_session_key_path 2>/dev/null || true)"
    [[ -n "$key" && -f "$key" ]] && {
        printf '%s\n' "$key"
        return 0
    }
    return 1
}

# Description: GIT_SSH_COMMAND for one repository (single deploy key when available).
# Arguments:
# - url: <String> Git remote URL
_nds_git_ssh_env_for_url() {
    local url="$1" key_path

    if key_path=$(_nds_git_identity_for_url "$url" 2>/dev/null); then
        printf '%s\n' \
            "GIT_TERMINAL_PROMPT=0" \
            "GIT_SSH_COMMAND=ssh -i \"${key_path}\" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
        return 0
    fi
    _nds_git_ssh_env
}

# Description: GIT_SSH_COMMAND and related env for non-interactive git/nix fetches.
_nds_git_ssh_env() {
    local key_path identity_args=() cfg wrapper
    local -a keys=()

    if nds_git_ssh_wrapper_active 2>/dev/null; then
        wrapper="$(nds_git_ssh_wrapper_path)"
        printf '%s\n' \
            "GIT_TERMINAL_PROMPT=0" \
            "GIT_SSH_COMMAND=${wrapper}"
        return 0
    fi

    cfg="$(nds_git_ssh_config_path)"
    if [[ -f "$cfg" ]] && grep -q IdentityFile "$cfg" 2>/dev/null; then
        printf '%s\n' \
            "GIT_TERMINAL_PROMPT=0" \
            "GIT_SSH_COMMAND=ssh -F ${cfg} -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
        return 0
    fi

    mapfile -t keys < <(nds_git_keys_list 2>/dev/null || true)
    if [[ ${#keys[@]} -eq 0 ]]; then
        key_path="$(nds_git_session_key_path 2>/dev/null || true)"
        [[ -n "$key_path" && -f "$key_path" ]] && keys=("$key_path")
    fi
    for key_path in "${keys[@]}"; do
        [[ -f "$key_path" ]] || continue
        identity_args+=(-i "$key_path")
    done
    if [[ ${#identity_args[@]} -gt 0 ]]; then
        identity_args+=(-o IdentitiesOnly=yes)
    fi
    printf '%s\n' \
        "GIT_TERMINAL_PROMPT=0" \
        "GIT_SSH_COMMAND=ssh ${identity_args[*]} -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
}

# Description: Environment for nix/git fetches during flake eval and nixos-install.
# Arguments:
# - out: <Array> Nameref to receive VAR=value pairs for env(1)
nds_git_export_nix_env() {
    local -n _out=$1
    _out=()
    while IFS= read -r line; do _out+=("$line"); done < <(_nds_git_ssh_env)
}
