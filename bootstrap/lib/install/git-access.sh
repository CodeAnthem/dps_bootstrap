#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access (private repo auth)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-04 | Modified: 2026-07-04
# Feature:       Interactive access gate + trace-free token clone wrapper (used by all clone sites)
# ==================================================================================================

# =============================================================================
# URL PARSING / CONVERSION
# =============================================================================

# Description: Split a git URL into host, owner, repo (repo without .git suffix).
# Handles https://, http://, git://, ssh:// and SCP-style user@host:owner/repo.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <String> "host<TAB>owner<TAB>repo" on stdout, non-zero when unparseable
_nds_git_parse() {
    local url="$1" host path rest
    case "$url" in
        *://*)
            rest="${url#*://}"
            rest="${rest#*@}"
            host="${rest%%/*}"
            path="${rest#*/}"
            ;;
        *@*:*)
            rest="${url#*@}"
            host="${rest%%:*}"
            path="${rest#*:}"
            ;;
        *)
            return 1
            ;;
    esac
    path="${path%.git}"
    path="${path%/}"
    [[ "$path" == */* ]] || return 1
    printf '%s\t%s\t%s\n' "$host" "${path%/*}" "${path##*/}"
}

_nds_git_to_https() { printf 'https://%s/%s/%s\n' "$1" "$2" "$3"; }
_nds_git_to_ssh() { printf 'git@%s:%s/%s.git\n' "$1" "$2" "$3"; }

# Description: Provider-specific URL where a read-only deploy key is added.
_nds_git_keys_url() {
    local host="$1" owner="$2" repo="$3"
    case "$host" in
        github.com|*.github.com) printf 'https://%s/%s/%s/settings/keys/new\n' "$host" "$owner" "$repo" ;;
        *gitlab*) printf 'https://%s/%s/%s/-/settings/repository  (Deploy keys)\n' "$host" "$owner" "$repo" ;;
        *) printf 'add a read-only deploy key for %s/%s on %s\n' "$owner" "$repo" "$host" ;;
    esac
}

# Description: Provider-specific URL where a read-only access token is created.
_nds_git_token_url() {
    local host="$1"
    case "$host" in
        github.com|*.github.com) printf 'https://%s/settings/tokens  (fine-grained, read-only "Contents")\n' "$host" ;;
        *gitlab*) printf 'https://%s/-/user_settings/personal_access_tokens  (read_repository)\n' "$host" ;;
        *) printf 'create a read-only access token on %s\n' "$host" ;;
    esac
}

# =============================================================================
# TOKEN PLUMBING (memory-only — never written to disk)
# =============================================================================

# Description: Path to an askpass helper. The script contains no secret; it reads
# _NDS_GIT_TOKEN from the environment at runtime.
_nds_git_askpass_file() {
    local f="${NDS_RUNTIME_DIR:-/tmp}/git-askpass.sh"
    if [[ ! -f "$f" ]]; then
        printf '#!/usr/bin/env bash\ncase "$1" in\n  *Username*) printf "%%s\\n" "x-access-token" ;;\n  *) printf "%%s\\n" "${_NDS_GIT_TOKEN:-}" ;;\nesac\n' > "$f"
        chmod 700 "$f"
    fi
    printf '%s\n' "$f"
}

# Description: Effective clone URL. With a token set, inject the x-access-token
# username so git only asks for a password (the token) via askpass; the token
# itself never appears in the URL.
_nds_git_effective_url() {
    local url="$1" rest
    if [[ -n "${_NDS_GIT_TOKEN:-}" && "$url" == https://* ]]; then
        rest="${url#https://}"
        rest="${rest#*@}"
        printf 'https://x-access-token@%s\n' "$rest"
    else
        printf '%s\n' "$url"
    fi
}

# Description: Session gitconfig (no credentials) mapping GitHub SSH URLs to HTTPS.
# Passed via GIT_CONFIG_GLOBAL so the operator's ~/.gitconfig is never touched.
_nds_git_session_config_file() {
    local f="${NDS_RUNTIME_DIR:-/tmp}/git-session.config"
    [[ -n "${_NDS_GIT_TOKEN:-}" ]] || return 0
    if [[ ! -f "$f" ]]; then
        git config --file "$f" url."https://github.com/".insteadOf "ssh://git@github.com/" 2>/dev/null || true
        git config --file "$f" url."https://github.com/".insteadOf "git+ssh://git@github.com/" 2>/dev/null || true
        git config --file "$f" url."https://github.com/".insteadOf "git@github.com:" 2>/dev/null || true
        chmod 600 "$f"
    fi
    printf '%s\n' "$f"
}

# Description: Append git auth env pairs (askpass + session gitconfig) to a nameref array.
# Arguments:
# - arr_name: <String> Name of the target array variable in the caller's scope
_nds_git_auth_env_append() {
    local -n __arr_ref="$1"
    [[ -n "${_NDS_GIT_TOKEN:-}" ]] || return 0
    local session_cfg
    session_cfg=$(_nds_git_session_config_file)
    __arr_ref+=(GIT_ASKPASS="$(_nds_git_askpass_file)" GIT_TERMINAL_PROMPT=0)
    __arr_ref+=(_NDS_GIT_TOKEN="${_NDS_GIT_TOKEN}")
    [[ -n "$session_cfg" ]] && __arr_ref+=(GIT_CONFIG_GLOBAL="$session_cfg")
}

# Description: NIX_CONFIG string for flake eval/build (access-tokens stays in env only).
nds_git_nix_config() {
    if [[ -n "${_NDS_GIT_TOKEN:-}" ]]; then
        printf 'experimental-features = nix-command flakes\naccess-tokens = github.com=%s' "$_NDS_GIT_TOKEN"
    else
        printf 'experimental-features = nix-command flakes'
    fi
}

# Description: Drop the in-memory token, askpass helper, and session gitconfig.
# Also scrubs legacy token-in-url rules from older NDS versions. Safe to call
# multiple times.
nds_git_access_cleanup() {
    local key
    if command -v git &>/dev/null; then
        while IFS= read -r key; do
            [[ -n "$key" ]] || continue
            git config --global --unset-all "$key" 2>/dev/null || true
        done < <(git config --global --get-regexp '^url\..*x-access-token.*\.insteadOf$' 2>/dev/null \
            | awk '{print $1}' || true)
    fi
    unset _NDS_GIT_TOKEN
    unset GIT_CONFIG_GLOBAL
    rm -f "${NDS_RUNTIME_DIR:-/tmp}/git-askpass.sh" 2>/dev/null || true
    rm -f "${NDS_RUNTIME_DIR:-/tmp}/git-session.config" 2>/dev/null || true
    rm -f "${NDS_RUNTIME_DIR:-/tmp}/nds-git-netrc" 2>/dev/null || true
}

# EXIT hook (main.sh) — wipe token state even when install aborts early.
hook_exit_cleanup() {
    nds_git_access_cleanup
}

# =============================================================================
# PROBE / CLONE
# =============================================================================

# Description: Non-interactively test whether a repo is reachable with current
# credentials (SSH keys and/or in-memory token). No prompts.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when accessible
nds_git_probe_access() {
    local url="$1" eff
    eff=$(_nds_git_effective_url "$url")
    local -a envv=(
        "GIT_TERMINAL_PROMPT=0"
        "GIT_SSH_COMMAND=ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15"
    )
    _nds_git_auth_env_append envv
    env "${envv[@]}" git -c credential.helper= ls-remote "$eff" &>/dev/null
}

# Description: Clone a flake using the configured access method. With a token, the
# clone is authenticated via askpass and the persisted remote is scrubbed back to
# the clean URL so no secret lands on the installed system.
# Arguments:
# - url:   <String> Clean git URL (no token)
# - dest:  <String> Destination directory
# - depth: <Int|optional> Clone depth (default 1; 0 = full clone)
# Returns:
# - <Bool> 0 on success
nds_git_clone() {
    local url="$1" dest="$2" depth="${3:-1}" eff rc
    eff=$(_nds_git_effective_url "$url")
    local -a envv=(
        "GIT_TERMINAL_PROMPT=0"
        "GIT_SSH_COMMAND=ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
    )
    _nds_git_auth_env_append envv

    if [[ "$depth" == "0" ]]; then
        env "${envv[@]}" git -c credential.helper= clone "$eff" "$dest"
    else
        env "${envv[@]}" git -c credential.helper= clone --depth "$depth" "$eff" "$dest"
    fi
    rc=$?

    if [[ $rc -eq 0 && -n "${_NDS_GIT_TOKEN:-}" ]]; then
        git -C "$dest" remote set-url origin "$url" 2>/dev/null || true
    fi
    return $rc
}

# =============================================================================
# ACCESS GATE
# =============================================================================

# Description: True when HTTPS token auth is offered (local live-ISO installs only).
_nds_git_token_allowed() {
    local mode
    mode="$(nds_configurator_config_get INSTALL_MODE 2>/dev/null || true)"
    mode="${mode:-$(nds_cfg_get INSTALL_MODE 2>/dev/null || true)}"
    mode="${mode:-local}"
    [[ "$mode" != "remote" ]]
}

# Description: Environment for nix/git fetches during flake eval and nixos-install.
# Applies in-memory HTTPS token auth when configured.
# Returns:
# - Sets _NDS_GIT_NIX_ENV array (nameref) of VAR=value pairs for env(1)
nds_git_export_nix_env() {
    local arr_name="$1"
    local -n __env_out="$arr_name"
    __env_out=()
    _nds_git_auth_env_append "$arr_name"
}

# Description: Extract git+ssh:// and ssh:// URLs from flake.lock (locked inputs).
# Arguments:
# - lock_file: <String> Path to flake.lock
# Returns:
# - <String> Newline-separated SSH URLs (stdout)
_nds_flake_lock_ssh_urls() {
    local lock_file="$1"
    [[ -f "$lock_file" ]] || return 0
    grep -oE '(git\+ssh|ssh)://[^"]+' "$lock_file" 2>/dev/null | sort -u || true
}

# Description: Rewrite GitHub SSH input URLs in a staged flake to git+https.
# Arguments:
# - flake_root: <String> Staged flake directory
_nds_rewrite_ssh_to_https() {
    local flake_root="$1"
    local lock="${flake_root}/flake.lock"
    local flake_nix="${flake_root}/flake.nix"

    if [[ -f "$lock" ]] && grep -qE 'ssh://git@github.com/|git\+ssh://git@github.com/' "$lock"; then
        sed -i \
            -e 's|git+ssh://git@github.com/|git+https://github.com/|g' \
            -e 's|ssh://git@github.com/|git+https://github.com/|g' \
            "$lock"
        nds_install_log "flake.lock: GitHub SSH inputs -> git+https"
    fi
    if [[ -f "$flake_nix" ]] && grep -q 'git+ssh://git@github.com/' "$flake_nix"; then
        sed -i 's|git+ssh://git@github.com/|git+https://github.com/|g' "$flake_nix"
    fi
    return 0
}

# Description: When using HTTPS token auth, rewrite SSH-style GitHub URLs in the
# staged flake to git+https (Nix uses git + GIT_ASKPASS; bare https:// 404s on
# private repos).
nds_flake_normalize_for_https_token() {
    [[ -n "${_NDS_GIT_TOKEN:-}" ]] || return 0
    log "Rewriting GitHub SSH flake input URLs to git+https (token auth)"
    _nds_rewrite_ssh_to_https "$1"
    return 0
}

# Description: Ensure transitive flake.lock SSH inputs are reachable. Decoupled from
# how the root flake was cloned — scans flake.lock and prompts for a memory-only
# token when SSH locked inputs exist and no deploy keys cover them.
# Arguments:
# - flake_root: <String> Staged or probe flake directory
# Returns:
# - <Bool> 0 when no SSH inputs, or token rewrite applied, or user declined token with SSH keys assumed
nds_flake_ensure_transitive_auth() {
    local flake_root="$1" lock ssh_urls url host

    lock="${flake_root}/flake.lock"
    ssh_urls="$(_nds_flake_lock_ssh_urls "$lock")"
    [[ -n "$ssh_urls" ]] || return 0

    if [[ -n "${_NDS_GIT_TOKEN:-}" ]]; then
        log "Rewriting transitive SSH flake inputs to git+https (token auth)"
        _nds_rewrite_ssh_to_https "$flake_root"
        return 0
    fi

    warn "Locked flake inputs use SSH — Nix fetches each with its locked URL:"
    while IFS= read -r url; do
        [[ -n "$url" ]] && warn "  $url"
    done <<< "$ssh_urls"

    if ! _nds_git_token_allowed; then
        warn "Remote install: ensure SSH keys on the operator machine for every repo above."
        return 1
    fi

    if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
        error "Transitive SSH inputs need a GitHub token or deploy keys on every repo"
        return 1
    fi

    host="github.com"
    url="${ssh_urls%%$'\n'*}"
    if parsed=$(_nds_git_parse "$url" 2>/dev/null); then
        IFS=$'\t' read -r host _ _ <<< "$parsed"
    fi

    nds_ui_b ""
    nds_ui_b "Your root flake may use SSH, but locked inputs above still need auth."
    nds_ui_b "A GitHub token (memory-only) rewrites those inputs to git+https for this session."
    if _nds_git_prompt_token "$host"; then
        log "Rewriting transitive SSH flake inputs to git+https (token auth)"
        _nds_rewrite_ssh_to_https "$flake_root"
        return 0
    fi

    error "Provide a token or deploy keys for every locked SSH input"
    return 1
}

# Legacy name used by preflight/orchestration.
nds_flake_normalize_lock_urls() {
    nds_flake_normalize_for_https_token "$1"
}

# Description: Bash fallback when jq is unavailable on the live ISO.
_nds_flake_github_override_args_bash() {
    local lock_file="$1" node="" in_locked=0 url="" rev="" line path owner repo

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]{4}\"([^\"]+)\":[[:space:]]*\{[[:space:]]*$ ]]; then
            node="${BASH_REMATCH[1]}"
            in_locked=0
            url=""
            rev=""
        fi
        [[ "$node" == "root" || -z "$node" ]] && continue
        [[ "$line" == *'"locked": {'* ]] && in_locked=1
        if [[ $in_locked -eq 1 ]]; then
            if [[ "$line" =~ \"url\":[[:space:]]*\"((git\+ssh|ssh)://git@github.com/[^\"]+)\" ]]; then
                url="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ \"rev\":[[:space:]]*\"([^\"]+)\" ]]; then
                rev="${BASH_REMATCH[1]}"
            fi
            if [[ "$line" =~ ^[[:space:]]*\},?[[:space:]]*$ && -n "$url" && -n "$rev" ]]; then
                path="${url#*github.com/}"
                path="${path%.git}"
                owner="${path%%/*}"
                repo="${path#*/}"
                if [[ -n "$owner" && -n "$repo" ]]; then
                    printf '%s\tgithub:%s/%s/%s\n' "$node" "$owner" "$repo" "$rev"
                fi
                in_locked=0
                url=""
                rev=""
            fi
        fi
    done < "$lock_file"
}

# Description: List github: override refs for SSH-locked GitHub nodes in flake.lock.
# Nix daemon honours access-tokens for github: fetches (unlike git+ssh / ssh://).
# Arguments:
# - lock_file: <String> Path to flake.lock
# Returns:
# - <String> Lines of "inputName<TAB>github:owner/repo/rev" (stdout)
_nds_flake_github_override_args() {
    local lock_file="$1"
    [[ -f "$lock_file" ]] || return 0
    [[ -n "${_NDS_GIT_TOKEN:-}" ]] || return 0
    if command -v jq &>/dev/null; then
        jq -r '
          .nodes // {} | to_entries[] |
          select(.value.locked.type? == "git") |
          select(.value.locked.url? // "" | test("(git\\+ssh|ssh)://git@github\\.com/")) |
          (.value.locked.url
            | sub("^(git\\+ssh|ssh)://git@github\\.com/"; "")
            | sub("\\.git$"; "")) as $slug |
          ($slug | split("/")) as $p |
          select(($p | length) >= 2) |
          "\(.key)\tgithub:\($p[0])/\($p[1])/\(.value.locked.rev)"
        ' "$lock_file" 2>/dev/null
    else
        _nds_flake_github_override_args_bash "$lock_file"
    fi
}

# Description: Append --override-input args for private GitHub SSH lock nodes.
# Arguments:
# - lock_file: <String> Path to flake.lock
# - arr_name:  <String> Name of caller array to append to
nds_flake_collect_github_overrides() {
    local lock_file="$1" arr_name="$2"
    local -n __ovr="$arr_name"
    local line name ref

    while IFS=$'\t' read -r name ref; do
        [[ -n "$name" && -n "$ref" ]] || continue
        __ovr+=(--override-input "$name" "$ref")
        log "flake override-input: ${name} -> ${ref}"
        nds_install_log "override-input ${name}=${ref}"
    done < <(_nds_flake_github_override_args "$lock_file")
}

# Description: Point FLAKE_* config + env at a new (converted) remote URL.
_nds_git_update_repo_url() {
    local new_url="$1"
    nds_cfg_set FLAKE_REPO_URL "$new_url"
    nds_cfg_set FLAKE_LOCATION "$new_url"
    nds_cfg_set FLAKE_LOCAL_PATH ""
    nds_cfg_set FLAKE_SOURCE "remote"
    export NDS_FLAKE_REPO_URL="$new_url"
    export NDS_FLAKE_SOURCE="remote"
}

# Description: Ensure an SSH deploy key exists, print it plus the provider URL,
# switch the clone URL to SSH, and wait for the user to register it.
_nds_git_setup_ssh() {
    local host="$1" owner="$2" repo="$3"
    local key="/root/.ssh/id_ed25519"

    mkdir -p /root/.ssh && chmod 700 /root/.ssh

    if [[ ! -f "$key" ]]; then
        if nds_askUserToProceed "No SSH key found. Generate one now?"; then
            if ! ssh-keygen -t ed25519 -N "" -f "$key" -C "nds-deploy-${repo:-host}" >/dev/null 2>&1; then
                error "ssh-keygen failed"
                return 1
            fi
        else
            return 1
        fi
    fi

    if ! ssh-add -l &>/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
        ssh-add "$key" >/dev/null 2>&1 || true
    fi

    if [[ -n "$host" && -n "$owner" && -n "$repo" ]]; then
        _nds_git_update_repo_url "$(_nds_git_to_ssh "$host" "$owner" "$repo")"
    fi

    nds_ui_b ""
    nds_ui_h "Add this public key as a read-only deploy key:"
    nds_ui_b ""
    console "$(cat "${key}.pub")"
    nds_ui_b ""
    nds_ui_b "Open: $(_nds_git_keys_url "$host" "$owner" "$repo")"
    nds_ui_b "Paste the key, keep write access OFF, and save."
    nds_ui_b ""
    nds_askUserToProceed "Added the deploy key — re-check access?" || return 1
    return 0
}

# Description: Collect an HTTPS access token (memory only). Does not change the
# root flake URL — use when transitive locked inputs need HTTPS auth.
# Arguments:
# - host: <String> Git host for token help URL (default github.com)
# Returns:
# - <Bool> 0 when a token was accepted
_nds_git_prompt_token() {
    local host="${1:-github.com}" token

    if ! _nds_git_token_allowed; then
        warn "HTTPS tokens are disabled for remote install — use SSH keys on the operator machine."
        return 1
    fi

    nds_ui_b ""
    nds_ui_h "HTTPS access token"
    nds_ui_b "Create a read-only token: $(_nds_git_token_url "$host")"
    nds_ui_b "The token stays in memory only — never written to disk or the backup."
    nds_ui_b ""
    read -rsp "${NDS_UI_INDENT_B}Paste token (hidden): " token < /dev/tty
    echo >&2
    if [[ -z "$token" ]]; then
        warn "No token entered."
        return 1
    fi
    export _NDS_GIT_TOKEN="$token"
    token=""
    nds_ui_b "  Token accepted (held in memory for this session)."
    return 0
}

# Description: Collect an HTTPS access token (memory only), switch the clone URL
# to HTTPS. The token is never stored in config, disk, or the backup bundle.
_nds_git_setup_token() {
    local host="$1" owner="$2" repo="$3"

    if [[ -n "$host" && -n "$owner" && -n "$repo" ]]; then
        _nds_git_update_repo_url "$(_nds_git_to_https "$host" "$owner" "$repo")"
    fi

    _nds_git_prompt_token "$host"
}

# Description: Gate a remote git flake behind an access check. If the repo is
# reachable (public, or existing keys work) this is a silent no-op. Otherwise it
# offers SSH deploy key or HTTPS token setup and loops until access works, the
# user retries, or skips. Local paths and empty URLs are ignored.
# Arguments:
# - url: <String> Flake git URL (or local path / empty — ignored)
# Returns:
# - <Bool> 0 when access is confirmed or the user chose to skip
nds_git_ensure_access() {
    local url="$1"
    [[ -n "$url" ]] || return 0
    case "$url" in
        http://*|https://*|git://*|ssh://*|*@*:*) ;;
        *) return 0 ;;
    esac

    if nds_git_probe_access "$url"; then
        debug "Git access OK: $url"
        return 0
    fi

    warn "Cannot access the flake repository without credentials — it looks private."
    nds_ui_b "Private flakes also need access to every locked input (e.g. thundercast)."

    if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
        warn "Auto-confirm on — skipping interactive git auth (clone may fail)."
        return 0
    fi

    local parsed host="" owner="" repo="" auth_choices auth_labels
    if parsed=$(_nds_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
    fi

    if _nds_git_token_allowed; then
        auth_choices="ssh|token|retry|skip"
        auth_labels="ssh=SSH deploy key|token=HTTPS access token (live ISO only)|retry=Re-check now|skip=Skip (try anyway)"
    else
        auth_choices="ssh|retry|skip"
        auth_labels="ssh=SSH key on this machine|retry=Re-check now|skip=Skip (try anyway)"
        nds_ui_b ""
        nds_ui_b "Remote install runs on your operator machine — use SSH keys loaded here."
        nds_ui_b "HTTPS tokens are only supported on the live ISO (memory-only, single session)."
    fi

    while true; do
        nds_ui_b ""
        nds_ui_h "Repository access"
        [[ -n "$owner" ]] && nds_ui_b "Repository: ${host}/${owner}/${repo}"
        nds_ui_b ""
        nds_cfg_ask_choice GIT_AUTH_METHOD "Auth method" "$auth_choices" "$auth_labels" "ssh"

        case "$(nds_cfg_get GIT_AUTH_METHOD)" in
            ssh)
                _nds_git_setup_ssh "$host" "$owner" "$repo" || continue
                url="$(nds_cfg_get FLAKE_REPO_URL)"
                ;;
            token)
                _nds_git_setup_token "$host" "$owner" "$repo" || continue
                url="$(nds_cfg_get FLAKE_REPO_URL)"
                ;;
            retry) ;;
            skip)
                warn "Continuing without configured git auth — the clone may fail."
                return 0
                ;;
        esac

        if nds_git_probe_access "$url"; then
            success "Git access confirmed."
            return 0
        fi
        warn "Still no access to the repository — try another method."
    done
}
