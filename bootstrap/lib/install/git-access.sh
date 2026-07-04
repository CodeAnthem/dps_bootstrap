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
# TOKEN PLUMBING (trace-free)
# =============================================================================

# Description: Path to an askpass helper that echoes the in-memory token. The
# file itself contains no secret — the token lives only in the exported env var.
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

# Description: Map GitHub SSH/HTTPS URLs to token-authenticated HTTPS for this
# session (live ISO only). Lets Nix fetch git+ssh flake inputs when the user
# chose HTTPS token auth for the root repo. Removed by nds_git_access_cleanup.
_nds_git_apply_token_instead_of() {
    [[ -n "${_NDS_GIT_TOKEN:-}" ]] || return 0
    local base="https://x-access-token:${_NDS_GIT_TOKEN}@github.com/"
    git config --global url."${base}".insteadOf "https://github.com/" 2>/dev/null || true
    git config --global url."${base}".insteadOf "ssh://git@github.com/" 2>/dev/null || true
    git config --global url."${base}".insteadOf "git+ssh://git@github.com/" 2>/dev/null || true
    git config --global url."${base}".insteadOf "git@github.com:" 2>/dev/null || true
}

# Description: Drop the in-memory token, askpass helper, and session git insteadOf
# rules. Safe to call multiple times.
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
    rm -f "${NDS_RUNTIME_DIR:-/tmp}/git-askpass.sh" 2>/dev/null || true
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
    [[ -n "${_NDS_GIT_TOKEN:-}" ]] && envv+=("GIT_ASKPASS=$(_nds_git_askpass_file)")
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
    [[ -n "${_NDS_GIT_TOKEN:-}" ]] && envv+=("GIT_ASKPASS=$(_nds_git_askpass_file)")

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

# Description: Environment for nix/git fetches during flake eval and nixos-install.
# Applies in-memory HTTPS token auth when configured.
# Returns:
# - Sets _NDS_GIT_NIX_ENV array (nameref) of VAR=value pairs for env(1)
nds_git_export_nix_env() {
    local -n _out=$1
    _out=()
    if [[ -n "${_NDS_GIT_TOKEN:-}" ]]; then
        _nds_git_apply_token_instead_of
        _out+=(GIT_ASKPASS="$(_nds_git_askpass_file)" GIT_TERMINAL_PROMPT=0)
    fi
}

# Description: When using HTTPS token auth, rewrite SSH-style GitHub URLs in the
# staged flake (belt-and-suspenders alongside git insteadOf).
nds_flake_normalize_for_https_token() {
    local flake_root="$1"
    local lock="${flake_root}/flake.lock"
    local flake_nix="${flake_root}/flake.nix"

    [[ -n "${_NDS_GIT_TOKEN:-}" ]] || return 0

    if [[ -f "$lock" ]] && grep -qE 'ssh://git@github.com/|git\+ssh://git@github.com/' "$lock"; then
        log "Rewriting GitHub SSH flake.lock input URLs to HTTPS (token auth)"
        sed -i \
            -e 's|git+ssh://git@github.com/|https://github.com/|g' \
            -e 's|ssh://git@github.com/|https://github.com/|g' \
            "$lock"
        nds_install_log "flake.lock: GitHub SSH inputs -> HTTPS"
    fi
    if [[ -f "$flake_nix" ]] && grep -q 'git+ssh://git@github.com/' "$flake_nix"; then
        log "Rewriting GitHub SSH flake.nix input URLs to HTTPS (token auth)"
        sed -i 's|git+ssh://git@github.com/|https://github.com/|g' "$flake_nix"
    fi
    return 0
}

# Legacy name used by preflight/orchestration.
nds_flake_normalize_lock_urls() {
    nds_flake_normalize_for_https_token "$1"
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

# Description: Collect an HTTPS access token (memory only), switch the clone URL
# to HTTPS. The token is never stored in config, disk, or the backup bundle.
_nds_git_setup_token() {
    local host="$1" owner="$2" repo="$3" token

    if [[ -n "$host" && -n "$owner" && -n "$repo" ]]; then
        _nds_git_update_repo_url "$(_nds_git_to_https "$host" "$owner" "$repo")"
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
    _nds_git_apply_token_instead_of
    nds_ui_b "  Token accepted (held in memory for this session)."
    return 0
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

    local parsed host="" owner="" repo=""
    if parsed=$(_nds_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
    fi

    while true; do
        nds_ui_b ""
        nds_ui_h "Repository access"
        [[ -n "$owner" ]] && nds_ui_b "Repository: ${host}/${owner}/${repo}"
        nds_ui_b ""
        nds_cfg_ask_choice GIT_AUTH_METHOD "Auth method" "ssh|token|retry|skip" \
            "ssh=SSH deploy key|token=HTTPS access token|retry=Re-check now|skip=Skip (try anyway)" "ssh"

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
