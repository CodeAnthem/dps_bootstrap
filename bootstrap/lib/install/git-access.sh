#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access (private repo auth)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-04 | Modified: 2026-07-04
# Feature:       Interactive SSH deploy-key gate + clone wrapper (used by all clone sites)
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

# Description: Normalize a remote URL to SSH for git operations.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <String> SSH URL on stdout (unchanged when already SSH or unparseable)
_nds_git_ssh_url() {
    local url="$1" parsed host owner repo
    case "$url" in
        git@*|ssh://*) printf '%s\n' "$url"; return 0 ;;
    esac
    if parsed=$(_nds_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        _nds_git_to_ssh "$host" "$owner" "$repo"
    else
        printf '%s\n' "$url"
    fi
}

# Description: GIT_SSH_COMMAND and related env for non-interactive git/ nix fetches.
_nds_git_ssh_env() {
    printf '%s\n' \
        "GIT_TERMINAL_PROMPT=0" \
        "GIT_SSH_COMMAND=ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30"
}

# Description: No-op hook kept for install action cleanup paths.
nds_git_access_cleanup() {
    :
}

# EXIT hook (main.sh) — reserved for session git cleanup.
hook_exit_cleanup() {
    nds_git_access_cleanup
}

# =============================================================================
# PROBE / CLONE
# =============================================================================

# Description: Non-interactively test whether a repo is reachable with loaded
# SSH keys. No prompts.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when accessible
nds_git_probe_access() {
    local url="$1" ssh_url
    ssh_url=$(_nds_git_ssh_url "$url")
    local -a envv=()
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env)
    env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
}

# Description: Clone a flake using SSH deploy-key auth.
# Arguments:
# - url:   <String> Git URL (HTTPS URLs are converted to SSH when parseable)
# - dest:  <String> Destination directory
# - depth: <Int|optional> Clone depth (default 1; 0 = full clone)
# Returns:
# - <Bool> 0 on success
nds_git_clone() {
    local url="$1" dest="$2" depth="${3:-1}" ssh_url
    ssh_url=$(_nds_git_ssh_url "$url")
    local -a envv=()
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env)

    if [[ "$depth" == "0" ]]; then
        env "${envv[@]}" git -c credential.helper= clone "$ssh_url" "$dest"
    else
        env "${envv[@]}" git -c credential.helper= clone --depth "$depth" "$ssh_url" "$dest"
    fi
}

# =============================================================================
# ACCESS GATE
# =============================================================================

# Description: Environment for nix/git fetches during flake eval and nixos-install.
# Returns:
# - Sets array (nameref) of VAR=value pairs for env(1)
nds_git_export_nix_env() {
    local -n _out=$1
    _out=()
    while IFS= read -r line; do _out+=("$line"); done < <(_nds_git_ssh_env)
}

# Description: Ensure ed25519 deploy key exists and is loaded in ssh-agent.
# Returns:
# - <Bool> 0 when a key is available
_nds_git_ensure_ssh_key() {
    local key="/root/.ssh/id_ed25519"

    mkdir -p /root/.ssh && chmod 700 /root/.ssh

    if [[ ! -f "$key" ]]; then
        if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
            return 1
        fi
        if ! nds_askUserToProceed "No SSH key found. Generate one now?"; then
            return 1
        fi
        if ! ssh-keygen -t ed25519 -N "" -f "$key" -C "nds-deploy" >/dev/null 2>&1; then
            error "ssh-keygen failed"
            return 1
        fi
    fi

    if ! ssh-add -l &>/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
        ssh-add "$key" >/dev/null 2>&1 || true
    fi
    return 0
}

# Description: Print the session deploy public key for registering on Git hosts.
_nds_git_show_deploy_key() {
    local key="/root/.ssh/id_ed25519.pub"
    [[ -f "$key" ]] || return 1
    nds_ui_b ""
    nds_ui_h "Add this public key as a read-only deploy key:"
    nds_ui_b ""
    console "$(cat "$key")"
    nds_ui_b ""
    nds_ui_b "Use the same key on every private repository listed below."
    nds_ui_b ""
    return 0
}

# Description: Extract git+ssh:// and ssh:// URLs from flake.lock.
# Arguments:
# - lock_file: <String> Path to flake.lock
# Returns:
# - <String> Newline-separated URLs (stdout)
_nds_flake_lock_ssh_urls() {
    local lock_file="$1"
    [[ -f "$lock_file" ]] || return 0
    grep -oE '(git\+ssh|ssh)://[^"]+' "$lock_file" 2>/dev/null | sort -u || true
}

# Description: Collect unique git remote URLs from a flake (lock, flake.nix, root URL).
# Arguments:
# - flake_root: <String> Flake directory
# - root_url:   <String|optional> Root flake git URL
# Returns:
# - <String> Newline-separated SSH-normalized clone URLs (stdout)
_nds_flake_collect_git_remote_urls() {
    local flake_root="$1" root_url="${2:-}"
    local lock="${flake_root}/flake.lock"
    local flake_nix="${flake_root}/flake.nix"
    declare -A seen=()
    local url norm

    _nds_flake_add_git_url() {
        local u="$1"
        [[ -n "$u" ]] || return 0
        norm=$(_nds_git_ssh_url "$u")
        [[ -n "$norm" ]] || return 0
        [[ -n "${seen[$norm]:-}" ]] && return 0
        seen[$norm]=1
        printf '%s\n' "$norm"
    }

    [[ -n "$root_url" ]] && _nds_flake_add_git_url "$root_url"

    if [[ -f "$lock" ]]; then
        while IFS= read -r url; do
            _nds_flake_add_git_url "$url"
        done < <(_nds_flake_lock_ssh_urls "$lock")
    fi

    if [[ -f "$flake_nix" ]]; then
        while IFS= read -r url; do
            _nds_flake_add_git_url "$url"
        done < <(grep -oE 'git\+ssh://[^"[:space:]]+|git@[^"[:space:]]+\.git' "$flake_nix" 2>/dev/null \
            | sort -u || true)
    fi
}

# Description: Probe SSH access to every git remote referenced by a flake closure.
# Runs before destructive install steps. Lists missing repos with deploy-key URLs.
# Arguments:
# - flake_root: <String> Probe or staged flake directory
# - root_url:   <String|optional> Root flake git URL
# Returns:
# - <Bool> 0 when all reachable or user chose skip
nds_git_ensure_flake_closure_access() {
    local flake_root="$1" root_url="${2:-}"
    local -a urls=() failed=()
    local url ssh_url parsed host owner repo choice

    [[ -d "$flake_root" ]] || { error "Flake root not found: $flake_root"; return 1; }

    mapfile -t urls < <(_nds_flake_collect_git_remote_urls "$flake_root" "$root_url")
    [[ ${#urls[@]} -gt 0 ]] || return 0

    log "Checking SSH access to ${#urls[@]} flake git input(s)"

    while true; do
        failed=()
        for url in "${urls[@]}"; do
            if nds_git_probe_access "$url"; then
                debug "Git access OK: $url"
            else
                failed+=("$url")
            fi
        done

        if [[ ${#failed[@]} -eq 0 ]]; then
            success "SSH access confirmed for all ${#urls[@]} flake git input(s)."
            nds_install_log "git: closure access OK (${#urls[@]} repos)"
            return 0
        fi

        warn "Missing SSH access to ${#failed[@]} of ${#urls[@]} repositories:"
        for url in "${failed[@]}"; do
            ssh_url=$(_nds_git_ssh_url "$url")
            if parsed=$(_nds_git_parse "$ssh_url"); then
                IFS=$'\t' read -r host owner repo <<< "$parsed"
                nds_ui_i "  ${owner}/${repo}"
                nds_ui_i "    $(_nds_git_keys_url "$host" "$owner" "$repo")"
            else
                nds_ui_i "  ${ssh_url}"
            fi
            nds_install_log "git: no access — ${ssh_url}"
        done

        if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
            error "Cannot verify SSH access to all flake git inputs"
            return 1
        fi

        nds_ui_b ""
        nds_cfg_ask_choice GIT_AUTH_METHOD "Next step" "ssh|retry|skip" \
            "ssh=Show deploy key|retry=Re-check now|skip=Skip (try anyway)" "ssh"

        choice="$(nds_cfg_get GIT_AUTH_METHOD)"
        case "$choice" in
            ssh)
                _nds_git_ensure_ssh_key || continue
                _nds_git_show_deploy_key || continue
                nds_askUserToProceed "Added deploy keys on the repos above — re-check?" || continue
                ;;
            retry) ;;
            skip)
                warn "Continuing without SSH access to every flake input — install may fail."
                return 0
                ;;
        esac
    done
}

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

    _nds_git_ensure_ssh_key || return 1

    if [[ -n "$host" && -n "$owner" && -n "$repo" ]]; then
        _nds_git_update_repo_url "$(_nds_git_to_ssh "$host" "$owner" "$repo")"
    fi

    _nds_git_show_deploy_key || return 1
    nds_ui_b "Open: $(_nds_git_keys_url "$host" "$owner" "$repo")"
    nds_ui_b "Paste the key, keep write access OFF, and save."
    nds_ui_b ""
    nds_ui_b "Use the same key on every private repository your flake depends on"
    nds_ui_b "(including locked inputs such as thundercast or thundercore)."
    nds_ui_b ""
    nds_askUserToProceed "Added the deploy key — re-check access?" || return 1
    return 0
}

# Description: Gate a remote git flake behind an SSH access check. If the repo
# is reachable (public, or existing keys work) this is a silent no-op. Otherwise
# it offers SSH deploy-key setup and loops until access works, the user retries,
# or skips. Local paths and empty URLs are ignored.
# Arguments:
# - url: <String> Flake git URL (or local path / empty — ignored)
# Returns:
# - <Bool> 0 when access is confirmed or the user chose to skip
nds_git_ensure_access() {
    local url="$1" parsed host="" owner="" repo=""
    [[ -n "$url" ]] || return 0
    case "$url" in
        http://*|https://*|git://*|ssh://*|*@*:*) ;;
        *) return 0 ;;
    esac

    if parsed=$(_nds_git_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$url" != git@* && "$url" != ssh://* ]]; then
            _nds_git_update_repo_url "$(_nds_git_to_ssh "$host" "$owner" "$repo")"
            url="$(nds_cfg_get FLAKE_REPO_URL)"
        fi
    fi

    if nds_git_probe_access "$url"; then
        debug "Git access OK: $url"
        return 0
    fi

    warn "Cannot access the flake repository without credentials — it looks private."
    nds_ui_b "Private flakes need SSH deploy keys on the root repo and every locked input."

    if [[ "${NDS_AUTO_CONFIRM:-false}" == "true" ]]; then
        warn "Auto-confirm on — skipping interactive git auth (clone may fail)."
        return 0
    fi

    while true; do
        nds_ui_b ""
        nds_ui_h "Repository access (SSH only)"
        [[ -n "$owner" ]] && nds_ui_b "Repository: ${host}/${owner}/${repo}"
        nds_ui_b ""
        nds_cfg_ask_choice GIT_AUTH_METHOD "Next step" "ssh|retry|skip" \
            "ssh=Set up SSH deploy key|retry=Re-check now|skip=Skip (try anyway)" "ssh"

        case "$(nds_cfg_get GIT_AUTH_METHOD)" in
            ssh)
                _nds_git_setup_ssh "$host" "$owner" "$repo" || continue
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
        warn "Still no access to the repository — add the deploy key or load an existing key."
    done
}
