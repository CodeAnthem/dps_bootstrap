#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH wrapper (per-repo deploy keys for nix/git)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# Description:   Repo-to-key map and git-ssh wrapper for nixos-install flake fetches
# ==================================================================================================

# Description: Tab-separated owner/repo -> private key map for this session.
nds_git_repo_key_map_file() {
    printf '%s/ssh/repo_key_map\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Record which private key belongs to a git repository.
# Arguments:
# - owner:    <String> Repository owner
# - repo:     <String> Repository name
# - key_path: <String> Private key path
nds_git_repo_key_map_set() {
    local owner="$1" repo="$2" key_path="$3"
    local map tmp line o r k

    [[ -n "$owner" && -n "$repo" && -f "$key_path" ]] || return 0
    map="$(nds_git_repo_key_map_file)"
    mkdir -p "$(dirname "$map")"
    tmp="${map}.new"
    : >"$tmp"
    if [[ -f "$map" ]]; then
        while IFS=$'\t' read -r o r k; do
            [[ -n "$o" && -n "$r" ]] || continue
            [[ "$o" == "$owner" && "$r" == "$repo" ]] && continue
            printf '%s\t%s\t%s\n' "$o" "$r" "$k" >>"$tmp"
        done <"$map"
    fi
    printf '%s\t%s\t%s\n' "$owner" "$repo" "$key_path" >>"$tmp"
    mv "$tmp" "$map"
    chmod 600 "$map"
    return 0
}

# Description: Path to the git-ssh wrapper used as GIT_SSH_COMMAND for nix/git.
nds_git_ssh_wrapper_path() {
    printf '%s/ssh/git-ssh\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Install or refresh the git-ssh wrapper and repo key map metadata.
nds_git_ssh_wrapper_refresh() {
    local wrapper map session_key

    map="$(nds_git_repo_key_map_file)"
    wrapper="$(nds_git_ssh_wrapper_path)"
    session_key="$(nds_git_session_key_path 2>/dev/null || true)"
    mkdir -p "$(dirname "$wrapper")"

    [[ -f "$map" ]] || touch "$map"
    chmod 600 "$map"

    cat >"$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
_map_file='${map}'
_session_key='${session_key}'
declare -A _repo_keys=()
if [[ -f "\$_map_file" ]]; then
    while IFS=\$'\t' read -r _o _r _k; do
        [[ -n "\$_o" && -n "\$_r" && -f "\$_k" ]] || continue
        _repo_keys["\${_o}/\${_r}"]="\$_k"
    done <"\$_map_file"
fi
_repo_slug=""
for _arg in "\$@"; do
    _s="\$_arg"
    _s="\${_s#\'}"
    _s="\${_s%\'}"
    _s="\${_s#git-upload-pack }"
    _s="\${_s%.git}"
    if [[ "\$_s" == */* && "\$_s" != *' '* && "\$_s" != *@* ]]; then
        _repo_slug="\$_s"
        break
    fi
done
_identity=()
if [[ -n "\$_repo_slug" && -n "\${_repo_keys[\$_repo_slug]:-}" ]]; then
    _identity=(-i "\${_repo_keys[\$_repo_slug]}" -o IdentitiesOnly=yes)
elif [[ -n "\$_session_key" && -f "\$_session_key" ]]; then
    _identity=(-i "\$_session_key" -o IdentitiesOnly=yes)
fi
exec ssh "\${_identity[@]}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 "\$@"
WRAPPER
    chmod 700 "$wrapper"
    return 0
}

# Description: Install git-ssh wrapper and repo map onto the target under /mnt.
# Arguments:
# - mount_root: <String|optional> Target mount (default /mnt)
nds_git_install_ssh_wrapper_to_target() {
    local mount_root="${1:-/mnt}"
    local map_src map_dest wrapper_dest profile_dir profile_file
    local -a keys=()
    local key_path base dest_rel o r k

    [[ -d "$mount_root" ]] || return 0
    map_src="$(nds_git_repo_key_map_file)"
    [[ -f "$map_src" ]] || return 0

    map_dest="${mount_root}/etc/nixos/secrets/nds_repo_key_map"
    wrapper_dest="${mount_root}/usr/local/bin/nds-git-ssh"
    mkdir -p "$(dirname "$map_dest")" "$(dirname "$wrapper_dest")"
    : >"${map_dest}.new"
    while IFS=$'\t' read -r o r k; do
        [[ -n "$o" && -n "$r" && -f "$k" ]] || continue
        base="$(basename "$k")"
        dest_rel="etc/nixos/secrets/${base}"
        printf '%s\t%s\t%s\n' "$o" "$r" "/${dest_rel}" >>"${map_dest}.new"
    done <"$map_src"
    mv "${map_dest}.new" "$map_dest"
    chmod 600 "$map_dest"

    cat >"$wrapper_dest" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
_map_file='/etc/nixos/secrets/nds_repo_key_map'
declare -A _repo_keys=()
if [[ -f "\$_map_file" ]]; then
    while IFS=\$'\t' read -r _o _r _k; do
        [[ -n "\$_o" && -n "\$_r" && -f "\$_k" ]] || continue
        _repo_keys["\${_o}/\${_r}"]="\$_k"
    done <"\$_map_file"
fi
_repo_slug=""
for _arg in "\$@"; do
    _s="\$_arg"
    _s="\${_s#\'}"
    _s="\${_s%\'}"
    _s="\${_s#git-upload-pack }"
    _s="\${_s%.git}"
    if [[ "\$_s" == */* && "\$_s" != *' '* && "\$_s" != *@* ]]; then
        _repo_slug="\$_s"
        break
    fi
done
_identity=()
if [[ -n "\$_repo_slug" && -n "\${_repo_keys[\$_repo_slug]:-}" ]]; then
    _identity=(-i "\${_repo_keys[\$_repo_slug]}" -o IdentitiesOnly=yes)
fi
exec ssh "\${_identity[@]}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 "\$@"
WRAPPER
    chmod 755 "$wrapper_dest"

    profile_dir="${mount_root}/etc/profile.d"
    profile_file="${profile_dir}/nds-git-ssh.sh"
    mkdir -p "$profile_dir"
    printf '%s\n' 'export GIT_SSH_COMMAND=/usr/local/bin/nds-git-ssh' >"$profile_file"
    chmod 644 "$profile_file"

    nds_install_log "git: target git-ssh wrapper -> /usr/local/bin/nds-git-ssh"
    return 0
}

nds_git_ssh_wrapper_active() {
    local wrapper map

    wrapper="$(nds_git_ssh_wrapper_path)"
    map="$(nds_git_repo_key_map_file)"
    [[ -x "$wrapper" && -f "$map" ]] || return 1
    [[ -s "$map" ]] && return 0
    [[ -n "$(nds_git_session_key_path 2>/dev/null || true)" ]] \
        && [[ -f "$(nds_git_session_key_path 2>/dev/null || true)" ]]
}
