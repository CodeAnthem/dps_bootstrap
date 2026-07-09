#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH key registry (multi-key / deploy-key support)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-08
# Description:   Registry file listing session private key paths (one per line).
_nds_git_keys_registry_file() {
    printf '%s/git_session_keys\n' "${NDS_RUNTIME_DIR:-/tmp/nds}"
}

# Description: Filesystem slug from owner and repo names.
# Arguments:
# - owner: <String> Git owner/org
# - repo:  <String> Repository name
# Returns:
# - <String> slug e.g. codeanthem-dps-swarm (stdout)
_nds_git_repo_slug() {
    local owner="$1" repo="$2"
    local o r

    o=$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')
    o=$(printf '%s' "$o" | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
    r=$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]')
    r=$(printf '%s' "$r" | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')
    printf '%s-%s\n' "$o" "$r"
}

# Description: Register a private key path for this NDS session.
# Arguments:
# - key_path: <String> Private key file
nds_git_keys_register() {
    local key_path="$1"
    local reg

    [[ -f "$key_path" ]] || return 1
    reg="$(_nds_git_keys_registry_file)"
    mkdir -p "$(dirname "$reg")"
    if [[ -f "$reg" ]] && grep -qxF "$key_path" "$reg" 2>/dev/null; then
        return 0
    fi
    printf '%s\n' "$key_path" >> "$reg"
    nds_git_key_load "$key_path" || true
    nds_git_ssh_config_refresh || true
    return 0
}

# Description: List registered session private key paths.
# Returns:
# - <String> paths (stdout, one per line)
nds_git_keys_list() {
    local reg key_path

    {
        reg="$(_nds_git_keys_registry_file)"
        if [[ -f "$reg" ]]; then
            while IFS= read -r key_path; do
                [[ -f "$key_path" ]] && printf '%s\n' "$key_path"
            done < "$reg"
        fi
        key_path="$(nds_git_session_key_path 2>/dev/null || true)"
        if [[ -n "$key_path" && -f "$key_path" ]]; then
            printf '%s\n' "$key_path"
        fi
    } | awk 'NF' | sort -u
}

# Description: Load all registered keys into ssh-agent.
nds_git_keys_load_all() {
    local key_path

    while IFS= read -r key_path; do
        [[ -n "$key_path" && -f "$key_path" ]] || continue
        nds_git_key_load "$key_path" || true
    done < <(nds_git_keys_list)
}

# Description: Persist auth mode for closure behaviour (deploy|account|imported).
# Arguments:
# - mode: <String> deploy, account, or imported
nds_git_auth_set_mode() {
    local mode="$1"
    export NDS_GIT_AUTH_MODE="$mode"
    nds_cfg_set GIT_AUTH_MODE "$mode"
}

# Description: Current git auth mode (deploy, account, imported, or empty).
# Returns:
# - <String> mode (stdout)
nds_git_auth_mode() {
    local mode="${NDS_GIT_AUTH_MODE:-}"
    [[ -n "$mode" ]] || mode="$(nds_cfg_get GIT_AUTH_MODE 2>/dev/null || true)"
    printf '%s\n' "$mode"
}

# Description: Slug for deploy key filenames (lowercase, underscores).
_nds_git_deploy_slug_part() {
    local s="$1"
    s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')
    printf '%s' "$s" | sed -e 's/[^a-z0-9]/_/g' -e 's/__*/_/g' -e 's/^_//' -e 's/_$//'
}

# Description: Basename for a per-repo deploy key file (local / target secrets).
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> e.g. nds_deploy_codeanthem_thundercast (stdout)
nds_git_deploy_key_basename() {
    local owner="$1" repo="$2"
    printf 'nds_deploy_%s_%s' "$(_nds_git_deploy_slug_part "$owner")" "$(_nds_git_deploy_slug_part "$repo")"
}

# Description: Session path for a per-repo deploy private key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> path under /root/.ssh (stdout)
nds_git_deploy_key_path() {
    local owner="$1" repo="$2" base="${NDS_GIT_DEPLOY_KEYS_DIR:-/root/.ssh}"
    printf '%s/%s\n' "$base" "$(nds_git_deploy_key_basename "$owner" "$repo")"
}

# Description: Deploy key title on GitHub (nds_<flake-host> — one name per machine).
# Arguments:
# - owner: <String> Ignored (kept for call-site compatibility)
# - repo:  <String> Ignored
# Returns:
# - <String> title e.g. nds_control-toolkit (stdout)
nds_git_deploy_key_title() {
    local name=""

    if declare -f nds_configurator_config_get &>/dev/null; then
        name="$(nds_configurator_config_get FLAKE_HOST 2>/dev/null || true)"
    fi
    [[ -z "$name" ]] && name="$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)"
    [[ -z "$name" ]] && name="$(nds_cfg_get NETWORK_HOSTNAME 2>/dev/null || true)"
    [[ -z "$name" ]] && name="$(hostname -s 2>/dev/null || echo live)"
    name=$(printf '%s' "$name" | sed -e 's/[^a-zA-Z0-9_-]/-/g' -e 's/--*/-/g')
    printf 'nds_%s' "$name"
}

# Description: Target install path relative to mount root for a deploy key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> e.g. root/.ssh/nds_deploy_codeanthem_thundercast (stdout)
nds_git_deploy_key_target_rel() {
    local owner="$1" repo="$2"
    printf 'root/.ssh/%s\n' "$(nds_git_deploy_key_basename "$owner" "$repo")"
}

# Description: Absolute path of nds-git-ssh helper in this NDS tree.
_nds_git_ssh_wrapper_src() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    printf '%s/nds-git-ssh.sh\n' "$here"
}

# Description: Absolute path of nds-switch helper in this NDS tree.
_nds_git_switch_src() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    printf '%s/nds-switch.sh\n' "$here"
}

# Description: Absolute path of nds-clean helper in this NDS tree.
_nds_git_clean_src() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    printf '%s/nds-clean.sh\n' "$here"
}

# Description: Official GitHub SSH host key lines (docs.github.com fingerprints).
# Returns:
# - <String> known_hosts lines (stdout)
nds_git_github_official_host_keys() {
    printf '%s\n' \
        "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" \
        "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=" \
        "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="
}

# Description: owner/repo slug from a deploy key basename (nds_deploy_owner_repo).
# Arguments:
# - base: <String> Filename basename
# Returns:
# - <String> owner/repo (stdout) or empty
_nds_git_owner_repo_from_deploy_basename() {
    local base="$1" rest owner repo

    [[ "$base" == nds_deploy_* ]] || return 1
    rest="${base#nds_deploy_}"
    owner="${rest%%_*}"
    repo="${rest#*_}"
    [[ -n "$owner" && -n "$repo" && "$repo" != "$rest" ]] || return 1
    printf '%s/%s\n' "$owner" "$repo"
}

# Description: Public key path for a per-repo deploy key.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <String> .pub path (stdout)
nds_git_deploy_key_pubkey_path() {
    printf '%s.pub\n' "$(nds_git_deploy_key_path "$1" "$2")"
}

# Description: Generate or reuse a deploy key for one repository.
# Arguments:
# - owner: <String> Git owner
# - repo:  <String> Repository name
# Returns:
# - <Bool> 0 on success
nds_git_deploy_key_generate() {
    local owner="$1" repo="$2"
    local dest title

    dest="$(nds_git_deploy_key_path "$owner" "$repo")"
    title="$(nds_git_deploy_key_title "$owner" "$repo")"
    nds_git_key_generate "$dest" "$title" || return 1
    nds_git_keys_register "$dest" || return 1
    nds_git_auth_set_mode deploy
    return 0
}

# Description: List deploy private key paths (session registry + nds_deploy_* on disk).
# Returns:
# - <String> paths (stdout, one per line)
_nds_git_collect_deploy_key_paths() {
    local deploy_dir="${NDS_GIT_DEPLOY_KEYS_DIR:-/root/.ssh}"
    local key_path

    {
        while IFS= read -r key_path; do
            [[ -f "$key_path" ]] && printf '%s\n' "$key_path"
        done < <(nds_git_keys_list 2>/dev/null || true)

        if [[ -d "$deploy_dir" ]]; then
            for key_path in "${deploy_dir}"/nds_deploy_*; do
                [[ -f "$key_path" ]] || continue
                [[ "$key_path" == *.pub ]] && continue
                printf '%s\n' "$key_path"
            done
        fi
    } | awk 'NF' | sort -u
}

# Description: Install GitHub host key for non-interactive git on the target.
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
_nds_git_install_github_known_hosts() {
    local mount_root="${1:-/mnt}"
    local kh="${mount_root}/etc/ssh/ssh_known_hosts"
    local kh_root="${mount_root}/root/.ssh/known_hosts"
    local line

    mkdir -p "${mount_root}/etc/ssh" "${mount_root}/root/.ssh"
    # Always replace stale/wrong github.com rows (accept-new cannot heal wrong keys).
    for kh in "$kh" "$kh_root"; do
        if [[ -f "$kh" ]]; then
            grep -vE '^github\.com[[:space:]]' "$kh" >"${kh}.nds.tmp" 2>/dev/null || : >"${kh}.nds.tmp"
            mv "${kh}.nds.tmp" "$kh"
        else
            : >"$kh"
        fi
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            printf '%s\n' "$line" >>"$kh"
        done < <(nds_git_github_official_host_keys)
        chmod 644 "$kh"
    done
    nds_install_log "git: github.com official host keys -> ssh_known_hosts"
}

# Description: Write nds-git.map lines for URLs whose deploy keys exist on target.
# Arguments:
# - mount_root: <String> Target mount
# - flake_root: <String|optional> Flake checkout (adds lock/flake URLs)
# Returns:
# - <String> map lines on stdout; count on fd3 as digits when available
_nds_git_write_deploy_map_lines() {
    local mount_root="$1" flake_root="${2:-}"
    local ssh_dir="${mount_root}/root/.ssh"
    local url ssh_url parsed host owner repo base dest want
    declare -A seen=()

    printf '# NDS map: owner/repo<TAB>/root/.ssh/nds_deploy_owner_repo\n'

    while IFS= read -r url; do
        [[ -n "$url" ]] || continue
        ssh_url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        [[ -n "$owner" && -n "$repo" ]] || continue
        want="$(printf '%s/%s' "${owner,,}" "${repo,,}")"
        [[ -n "${seen[$want]:-}" ]] && continue
        base="$(nds_git_deploy_key_basename "$owner" "$repo")"
        dest="${ssh_dir}/${base}"
        [[ -f "$dest" ]] || continue
        seen[$want]=1
        printf '%s\t/root/.ssh/%s\n' "$want" "$base"
    done < <(
        if [[ -n "$flake_root" && -d "$flake_root" ]]; then
            _nds_flake_collect_git_remote_urls "$flake_root" "${NDS_CTX_FLAKE_REPO_URL:-${NDS_FLAKE_REPO_URL:-}}"
        elif [[ -n "${NDS_CTX_FLAKE_REPO_URL:-${NDS_FLAKE_REPO_URL:-}}" ]]; then
            _nds_git_ssh_url "${NDS_CTX_FLAKE_REPO_URL:-$NDS_FLAKE_REPO_URL}"
        fi
    )

    # Fallback: reconstruct from deployed basenames (simple owner_repo; underscore-safe via URLs above)
    for dest in "${ssh_dir}"/nds_deploy_*; do
        [[ -f "$dest" ]] || continue
        [[ "$dest" == *.pub ]] && continue
        base="$(basename "$dest")"
        want="$(_nds_git_owner_repo_from_deploy_basename "$base" 2>/dev/null || true)"
        [[ -n "$want" ]] || continue
        want="${want,,}"
        [[ -n "${seen[$want]:-}" ]] && continue
        seen[$want]=1
        printf '%s\t/root/.ssh/%s\n' "$want" "$base"
    done
}

# Description: Write owner/repo → key map and install nds-git-ssh + GIT_SSH_COMMAND.
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
# - flake_root: <String|optional> Flake checkout for URL→key map
_nds_git_install_ssh_wrapper_to_target() {
    local mount_root="${1:-/mnt}"
    local flake_root="${2:-}"
    local ssh_dir="${mount_root}/root/.ssh"
    local map_file="${ssh_dir}/nds-git.map"
    local wrap_dst="${ssh_dir}/nds-git-ssh"
    local switch_src switch_dst wrap_src env_dir env_file installed_map=0

    # NixOS: prefer /root/.nds/bin (survives self-update); keep profile.d PATH tip.
    mkdir -p "$ssh_dir" "${mount_root}/etc/environment.d" \
        "${mount_root}/root/bin" "${mount_root}/root/.nds/bin" "${mount_root}/etc/profile.d"
    wrap_src="$(_nds_git_ssh_wrapper_src)"
    [[ -f "$wrap_src" ]] || {
        error "nds-git-ssh source missing: ${wrap_src}"
        return 1
    }
    if [[ "$(id -u)" -eq 0 ]]; then
        install -m 755 -o root -g root "$wrap_src" "$wrap_dst"
    else
        install -m 755 "$wrap_src" "$wrap_dst"
    fi

    switch_src="$(_nds_git_switch_src)"
    switch_dst="${mount_root}/root/.nds/bin/nds-switch"
    clean_src="$(_nds_git_clean_src)"
    clean_dst="${mount_root}/root/.nds/bin/nds-clean"
    if [[ -f "$switch_src" ]]; then
        if [[ "$(id -u)" -eq 0 ]]; then
            install -m 755 -o root -g root "$switch_src" "$switch_dst"
            install -m 755 -o root -g root "$wrap_src" "${mount_root}/root/.nds/bin/nds-git-ssh"
        else
            install -m 755 "$switch_src" "$switch_dst"
            install -m 755 "$wrap_src" "${mount_root}/root/.nds/bin/nds-git-ssh"
        fi
        if [[ -f "$clean_src" ]]; then
            if [[ "$(id -u)" -eq 0 ]]; then
                install -m 755 -o root -g root "$clean_src" "$clean_dst"
            else
                install -m 755 "$clean_src" "$clean_dst"
            fi
            cp -f "$clean_dst" "${mount_root}/root/bin/nds-clean"
            chmod 755 "${mount_root}/root/bin/nds-clean"
        fi
        # Legacy + convenience copies
        cp -f "$switch_dst" "${mount_root}/root/bin/nds-switch"
        cp -f "$switch_dst" "${ssh_dir}/nds-switch"
        chmod 755 "${mount_root}/root/bin/nds-switch" "${ssh_dir}/nds-switch"
        printf 'export PATH="/root/.nds/bin:/root/bin:${PATH}"\n' \
            >"${mount_root}/etc/profile.d/nds-root-bin.sh"
        chmod 644 "${mount_root}/etc/profile.d/nds-root-bin.sh"
        _nds_git_append_root_path_snippet() {
            local dotfile="$1"
            local target="${mount_root}/root/${dotfile}"
            grep -q '/root/.nds/bin' "$target" 2>/dev/null \
                && return 0
            if [[ -f "$target" ]]; then
                printf '\n# NDS helpers\nexport PATH="/root/.nds/bin:/root/bin:$PATH"\n[ -x /root/.nds/bin/nds-git-ssh ] && export GIT_SSH_COMMAND=/root/.nds/bin/nds-git-ssh\n' >>"$target"
            else
                printf '# NDS helpers\nexport PATH="/root/.nds/bin:/root/bin:$PATH"\n[ -x /root/.nds/bin/nds-git-ssh ] && export GIT_SSH_COMMAND=/root/.nds/bin/nds-git-ssh\n' >"$target"
            fi
            chmod 644 "$target"
        }
        # SSH login reads .bash_profile first; tty login reads .profile
        _nds_git_append_root_path_snippet .bash_profile
        _nds_git_append_root_path_snippet .profile
        _nds_git_append_root_path_snippet .bashrc
        nds_install_log "git: nds-switch -> /root/.nds/bin/nds-switch"
        [[ -f "$clean_src" ]] && nds_install_log "git: nds-clean -> /root/.nds/bin/nds-clean"
    else
        warn "nds-switch source missing: ${switch_src}"
    fi

    _nds_git_write_deploy_map_lines "$mount_root" "$flake_root" >"$map_file"
    installed_map=$(grep -cvE '^(#|$)' "$map_file" 2>/dev/null || echo 0)
    # grep can print "0\n0" on some versions when file is empty-ish — take first integer
    installed_map="${installed_map%%$'\n'*}"
    installed_map="${installed_map:-0}"
    chmod 600 "$map_file"

    env_dir="${mount_root}/etc/environment.d"
    env_file="${env_dir}/50-nds-git-ssh.conf"
    printf 'GIT_SSH_COMMAND=/root/.ssh/nds-git-ssh\n' >"$env_file"
    chmod 644 "$env_file"

    mkdir -p "${mount_root}/etc/profile.d"
    printf 'export GIT_SSH_COMMAND=/root/.ssh/nds-git-ssh\n' \
        >"${mount_root}/etc/profile.d/nds-git-ssh.sh"
    chmod 644 "${mount_root}/etc/profile.d/nds-git-ssh.sh"

    # Login shells / nixos-rebuild as root
    if [[ ! -f "${ssh_dir}/.nds-git-ssh-profile" ]]; then
        printf 'export GIT_SSH_COMMAND=/root/.ssh/nds-git-ssh\n' >"${ssh_dir}/.nds-git-ssh-profile"
        chmod 644 "${ssh_dir}/.nds-git-ssh-profile"
    fi
    mkdir -p "${mount_root}/root"
    if [[ -f "${mount_root}/root/.bash_profile" ]]; then
        grep -q 'nds-git-ssh-profile' "${mount_root}/root/.bash_profile" 2>/dev/null \
            || printf '\n# NDS git+ssh deploy keys\n[ -f /root/.ssh/.nds-git-ssh-profile ] && . /root/.ssh/.nds-git-ssh-profile\n' \
                >>"${mount_root}/root/.bash_profile"
    else
        printf '# NDS git+ssh deploy keys\n[ -f /root/.ssh/.nds-git-ssh-profile ] && . /root/.ssh/.nds-git-ssh-profile\n' \
            >"${mount_root}/root/.bash_profile"
        chmod 644 "${mount_root}/root/.bash_profile"
    fi

    nds_install_log "git: nds-git-ssh + map (${installed_map} entries) -> /root/.ssh/"
    _nds_git_install_github_known_hosts "$mount_root"
    [[ "$installed_map" -gt 0 ]]
}

# Description: Prove target can ls-remote private flake git inputs via nds-git-ssh.
# Arguments:
# - mount_root: <String> Target mount (default /mnt)
# - flake_root: <String> Flake checkout on target (e.g. /mnt/etc/nixos)
# Returns:
# - <Bool> 0 when all private SSH remotes probe OK
nds_git_verify_target_ro_access() {
    local mount_root="${1:-/mnt}"
    local flake_root="${2:-}"
    local wrap="${mount_root}/root/.ssh/nds-git-ssh"
    local url ssh_url rc=0 fail=0 probed=0

    [[ -x "$wrap" ]] || {
        error "nds-git-ssh missing on target (${wrap})"
        return 1
    }
    [[ -n "$flake_root" && -d "$flake_root" ]] || {
        error "Flake root missing for git RO verify: ${flake_root}"
        return 1
    }

    while IFS= read -r url; do
        [[ -n "$url" ]] || continue
        ssh_url=$(_nds_git_ssh_url "$url")
        if nds_git_probe_public "$ssh_url" 2>/dev/null; then
            debug "Target skip public: ${ssh_url}"
            continue
        fi
        probed=$((probed + 1))
        if command -v timeout &>/dev/null; then
            timeout 20 env GIT_SSH_COMMAND="$wrap" NDS_GIT_SSH_ROOT="$mount_root" \
                GIT_TERMINAL_PROMPT=0 \
                git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
        else
            env GIT_SSH_COMMAND="$wrap" NDS_GIT_SSH_ROOT="$mount_root" \
                GIT_TERMINAL_PROMPT=0 \
                git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
        fi || rc=$?
        if [[ "${rc:-0}" -ne 0 ]]; then
            error "Target git RO probe failed: ${ssh_url}"
            fail=$((fail + 1))
        else
            nds_install_log "git: target probe OK ${ssh_url}"
        fi
        rc=0
    done < <(_nds_flake_collect_git_remote_urls "$flake_root" "${NDS_CTX_FLAKE_REPO_URL:-${NDS_FLAKE_REPO_URL:-}}")

    [[ "$fail" -eq 0 ]] || return 1
    [[ "$probed" -gt 0 ]] && nds_install_log "git: target RO probes OK (${probed} private)"
    return 0
}

# Description: Install deploy keys under /mnt/root/.ssh and wire nds-git-ssh.
# Arguments:
# - mount_root: <String|optional> Target mount (default /mnt)
# - flake_root: <String|optional> Flake checkout (map + verify)
# Returns:
# - <Bool> 0 on success; 1 when private inputs need keys but none installed
nds_git_install_keys_to_target() {
    local mount_root="${1:-/mnt}"
    local flake_root="${2:-${NDS_CTX_FLAKE_INSTALL_PATH:-${NDS_FLAKE_INSTALL_PATH:-}}}"
    local -a keys=()
    local key_path base dest_rel dest installed=0
    local need_private=false url

    [[ -d "$mount_root" ]] || {
        debug "Target mount missing — skip git SSH key install"
        return 0
    }

    if [[ -n "$flake_root" && -d "$flake_root" ]]; then
        while IFS= read -r url; do
            [[ -n "$url" ]] || continue
            if ! nds_git_probe_public "$(_nds_git_ssh_url "$url")" 2>/dev/null; then
                need_private=true
                break
            fi
        done < <(_nds_flake_collect_git_remote_urls "$flake_root" "${NDS_CTX_FLAKE_REPO_URL:-${NDS_FLAKE_REPO_URL:-}}")
    else
        # No flake root yet — if deploy keys exist in session, still install them.
        need_private=true
    fi

    mapfile -t keys < <(_nds_git_collect_deploy_key_paths)
    # Prefer only nds_deploy_* files for target wiring
    local -a deploy_keys=()
    for key_path in "${keys[@]}"; do
        [[ -f "$key_path" ]] || continue
        [[ "$(basename "$key_path")" == nds_deploy_* ]] || continue
        deploy_keys+=("$key_path")
    done

    if [[ ${#deploy_keys[@]} -eq 0 ]]; then
        if [[ "$need_private" == "true" ]]; then
            error "No deploy keys to install (need nds_deploy_* under ${NDS_GIT_DEPLOY_KEYS_DIR:-/root/.ssh})"
            return 1
        fi
        nds_install_log "git: no private flake inputs — skip deploy key install"
        return 0
    fi

    mkdir -p "${mount_root}/root/.ssh"
    chmod 700 "${mount_root}/root/.ssh"
    for key_path in "${deploy_keys[@]}"; do
        base="$(basename "$key_path")"
        dest_rel="root/.ssh/${base}"
        dest="${mount_root}/${dest_rel}"
        if [[ "$(id -u)" -eq 0 ]]; then
            install -m 600 -o root -g root "$key_path" "$dest"
            [[ -f "${key_path}.pub" ]] && install -m 644 -o root -g root "${key_path}.pub" "${dest}.pub"
        else
            install -m 600 "$key_path" "$dest"
            [[ -f "${key_path}.pub" ]] && install -m 644 "${key_path}.pub" "${dest}.pub"
        fi
        nds_install_log "git: SSH key -> /${dest_rel}"
        installed=$((installed + 1))
    done

    [[ "$installed" -gt 0 ]] || {
        error "No nds_deploy_* keys were copied to target /root/.ssh"
        return 1
    }

    _nds_git_install_ssh_wrapper_to_target "$mount_root" "$flake_root" || return 1

    if [[ "$need_private" == "true" && -n "$flake_root" && -d "$flake_root" ]]; then
        nds_git_verify_target_ro_access "$mount_root" "$flake_root" || return 1
    fi
    return 0
}
