#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub CLI session helpers (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-03
# Description:   gh binary resolve, prefetch, session login/cleanup helpers
#                (boot cache + multi-home hosts.yml detection)
# ==================================================================================================

# Description: Nix CLI prefix for gh on live ISO (flakes required).
_git_gh_nix() {
    nix --extra-experimental-features "nix-command flakes" "$@"
}

# Boot-persistent path to the last resolved gh binary (survives NDS restarts on the ISO).
: "${NDS_GIT_GH_BIN_CACHE_FILE:=/tmp/nds-gh-bin}"

# Description: Persist NDS_GIT_GH_BIN so the next NDS start can reuse it.
_git_gh_persist_bin_cache() {
    [[ -n "${NDS_GIT_GH_BIN:-}" && -x "${NDS_GIT_GH_BIN}" ]] || return 1
    printf '%s\n' "$NDS_GIT_GH_BIN" >"$NDS_GIT_GH_BIN_CACHE_FILE" 2>/dev/null || true
}

# Description: Restore NDS_GIT_GH_BIN from /tmp cache when the store path still exists.
_git_gh_restore_bin_cache() {
    local p
    [[ -f "$NDS_GIT_GH_BIN_CACHE_FILE" ]] || return 1
    p="$(<"$NDS_GIT_GH_BIN_CACHE_FILE")"
    [[ -n "$p" && -x "$p" ]] || return 1
    NDS_GIT_GH_BIN="$p"
    export NDS_GIT_GH_BIN
    return 0
}

# Description: Candidate gh hosts.yml paths (root + live-ISO user + sudo user).
# Prints unique existing-or-likely paths (stdout), one per line.
_git_gh_hosts_yml_candidates() {
    local -A seen=()
    local f h
    local -a candidates=()

    [[ -n "${GH_CONFIG_DIR:-}" ]] && candidates+=("${GH_CONFIG_DIR}/hosts.yml")
    [[ -n "${XDG_CONFIG_HOME:-}" ]] && candidates+=("${XDG_CONFIG_HOME}/gh/hosts.yml")
    candidates+=("${HOME:-/root}/.config/gh/hosts.yml")
    candidates+=("/root/.config/gh/hosts.yml")
    candidates+=("/home/nixos/.config/gh/hosts.yml")

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        h="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)"
        [[ -n "$h" ]] && candidates+=("${h}/.config/gh/hosts.yml")
    fi

    for f in "${candidates[@]}"; do
        [[ -n "$f" ]] || continue
        [[ -n "${seen[$f]:-}" ]] && continue
        seen[$f]=1
        printf '%s\n' "$f"
    done
}

# Description: True when a real gh binary is ready (PATH or NDS_GIT_GH_BIN).
# Does not count nix shell fallback — that re-evals on every call.
nds_git_gh_bin_ready() {
    if command -v gh &>/dev/null; then
        return 0
    fi
    if [[ -n "${NDS_GIT_GH_BIN:-}" && -x "${NDS_GIT_GH_BIN}" ]]; then
        return 0
    fi
    _git_gh_restore_bin_cache
}

# Description: Resolve gh from PATH or NDS_GIT_GH_BIN only (never downloads).
# Arguments:
# - out: <Nameref> Command prefix array
# Returns:
# - <Bool> 0 when a real binary is ready
nds_git_gh_cmd_nofetch() {
    local -n _out=$1
    if command -v gh &>/dev/null; then
        _out=(gh)
        return 0
    fi
    if [[ -z "${NDS_GIT_GH_BIN:-}" || ! -x "${NDS_GIT_GH_BIN}" ]]; then
        _git_gh_restore_bin_cache || true
    fi
    if [[ -n "${NDS_GIT_GH_BIN:-}" && -x "${NDS_GIT_GH_BIN}" ]]; then
        _out=("${NDS_GIT_GH_BIN}")
        return 0
    fi
    _out=()
    return 1
}

# Description: Resolve gh command (host binary or cached nix store path).
# Prefers PATH / NDS_GIT_GH_BIN. Auto-prefetches once when only nix is available.
# Arguments:
# - out: <Nameref> Command prefix array
# Returns:
# - <Bool> 0 when gh is available
nds_git_gh_cmd() {
    local -n _out=$1
    local -a _resolved=()
    if nds_git_gh_cmd_nofetch _resolved; then
        _out=("${_resolved[@]}")
        return 0
    fi
    if command -v nix &>/dev/null; then
        # One-time cache — never leave callers on perpetual `nix shell`.
        if nds_git_gh_prefetch && nds_git_gh_cmd_nofetch _resolved; then
            _out=("${_resolved[@]}")
            return 0
        fi
        _out=(_git_gh_nix shell nixpkgs#gh -c gh)
        return 0
    fi
    _out=()
    return 1
}

# Description: True when gh hosts.yml still lists github.com (leftover ISO login).
# Checks root, current HOME, live-ISO nixos user, and SUDO_USER home.
nds_git_gh_hosts_yml_has_github() {
    local f
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        grep -qE '^[[:space:]]*['\''"]?github\.com['\''"]?:' "$f" 2>/dev/null && return 0
    done < <(_git_gh_hosts_yml_candidates)
    return 1
}

# Description: Remove leftover gh host config files on the live ISO (all known homes).
_git_gh_wipe_hosts_yml() {
    local f
    while IFS= read -r f; do
        [[ -f "$f" ]] && rm -f "$f"
    done < <(_git_gh_hosts_yml_candidates)
}

# Description: True when gh auth status reports logged-in for a given HOME.
# Arguments:
# - home: <String> HOME directory to use for gh config lookup
_git_gh_auth_status_home() {
    local home="$1"
    local -a gh_cmd=()
    local status_out

    nds_git_gh_cmd_nofetch gh_cmd || return 1
    status_out="$(HOME="$home" "${gh_cmd[@]}" auth status -h github.com 2>&1)" || status_out=""
    if grep -qiE 'Logged in to github\.com|✓.*github\.com|github\.com account' <<<"$status_out"; then
        return 0
    fi
    HOME="$home" "${gh_cmd[@]}" auth status -h github.com &>/dev/null
}

# Description: True when gh reports a logged-in github.com host, or leftover hosts.yml.
# Never downloads gh. Checks auth status under /root and /home/nixos (sudo HOME
# often hides a live-ISO user session), then hosts.yml in all known homes.
nds_git_gh_host_logged_in() {
    local home h
    local -a gh_cmd=()

    if nds_git_gh_cmd_nofetch gh_cmd; then
        for home in "${HOME:-/root}" /root /home/nixos; do
            [[ -d "$home" ]] || continue
            _git_gh_auth_status_home "$home" && return 0
        done
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            h="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)"
            if [[ -n "$h" && -d "$h" ]]; then
                _git_gh_auth_status_home "$h" && return 0
            fi
        fi
    fi

    # Leftover config under /home/nixos or other homes (sudo HOME=/root misses these)
    nds_git_gh_hosts_yml_has_github
}

# Description: True when gh is logged in to github.com (flag or live check).
nds_git_gh_session_active() {
    [[ "${NDS_GIT_GH_SESSION_ACTIVE:-}" == "true" ]] && return 0
    if nds_git_gh_host_logged_in; then
        NDS_GIT_GH_SESSION_ACTIVE=true
        export NDS_GIT_GH_SESSION_ACTIVE
        nds_git_gh_probe_registration_scopes && nds_git_gh_session_mark_scopes_ok || true
        return 0
    fi
    return 1
}

# Description: Mark gh session active after successful device login.
nds_git_gh_session_mark_active() {
    NDS_GIT_GH_SESSION_ACTIVE=true
    export NDS_GIT_GH_SESSION_ACTIVE
    NDS_GIT_GH_LEFTOVER=true
    export NDS_GIT_GH_LEFTOVER
}

# Description: Mark gh token scopes as sufficient for deploy/account key registration.
nds_git_gh_session_mark_scopes_ok() {
    NDS_GIT_GH_HAS_KEY_SCOPE=true
    export NDS_GIT_GH_HAS_KEY_SCOPE
    nds_git_gh_session_mark_active
}

# Description: True when gh token has scopes needed for key registration.
nds_git_gh_probe_registration_scopes() {
    local -a gh_cmd=()
    local out

    nds_git_gh_cmd gh_cmd || return 1
    out=$("${gh_cmd[@]}" auth status --show-token-scopes 2>&1) || true
    if grep -qiE 'admin:public_key|\brepo\b' <<< "$out"; then
        return 0
    fi
    out=$("${gh_cmd[@]}" auth status 2>&1) || return 1
    grep -qiE 'admin:public_key|\brepo\b|Token scopes:.*repo' <<< "$out"
}

# Description: True when token has admin:public_key or repo scope.
nds_git_gh_has_key_scope() {
    [[ "${NDS_GIT_GH_HAS_KEY_SCOPE:-}" == "true" ]] && return 0
    if nds_git_gh_probe_registration_scopes; then
        nds_git_gh_session_mark_scopes_ok
        return 0
    fi
    return 1
}

# Description: End temporary gh auth on the live ISO (SSH keys on GitHub are kept).
# Uses non-interactive logout (--yes); falls back to wiping hosts.yml for insecure-storage.
# Prefetches gh only when a leftover session exists and no binary is cached yet.
# Returns:
# - <Bool> 0 when no session remains (or nothing to clear)
nds_git_gh_session_cleanup() {
    local -a gh_cmd=()
    local home h
    local had_session=false

    if nds_git_gh_host_logged_in || [[ "${NDS_GIT_GH_LEFTOVER:-}" == "true" ]] \
        || [[ "${NDS_GIT_GH_SESSION_ACTIVE:-}" == "true" ]]; then
        had_session=true
    else
        return 0
    fi

    unset NDS_GIT_GH_SESSION_ACTIVE 2>/dev/null || true
    unset NDS_GIT_GH_HAS_KEY_SCOPE 2>/dev/null || true
    unset NDS_GIT_GH_LEFTOVER 2>/dev/null || true

    # Prefer an already-cached binary; only download when clearing a real leftover session.
    if ! nds_git_gh_cmd_nofetch gh_cmd; then
        if nds_git_gh_ensure_prefetch; then
            nds_git_gh_cmd_nofetch gh_cmd || true
        fi
    fi

    if [[ ${#gh_cmd[@]} -gt 0 ]]; then
        for home in "${HOME:-/root}" /root /home/nixos; do
            [[ -d "$home" ]] || continue
            HOME="$home" "${gh_cmd[@]}" auth logout --hostname github.com --yes &>/dev/null \
                || HOME="$home" "${gh_cmd[@]}" auth logout --hostname github.com -y &>/dev/null \
                || printf 'y\n' | HOME="$home" "${gh_cmd[@]}" auth logout --hostname github.com &>/dev/null \
                || true
        done
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            h="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6 || true)"
            if [[ -n "$h" && -d "$h" ]]; then
                HOME="$h" "${gh_cmd[@]}" auth logout --hostname github.com --yes &>/dev/null \
                    || HOME="$h" "${gh_cmd[@]}" auth logout --hostname github.com -y &>/dev/null \
                    || true
            fi
        fi
    fi

    # Always wipe leftover host config across known homes on the live ISO
    _git_gh_wipe_hosts_yml

    if nds_git_gh_host_logged_in; then
        warn "Could not clear gh session on this ISO"
        return 1
    fi

    if [[ "$had_session" == "true" ]]; then
        success "Cleared gh session from this live ISO (SSH keys on GitHub were kept)"
        nds_install_log "git: gh session cleared from live ISO (SSH key left on GitHub)"
    fi
    return 0
}

# Description: True when gh can be obtained (cached binary, PATH, or via nix).
nds_git_gh_available() {
    nds_git_gh_bin_ready && return 0
    command -v nix &>/dev/null
}

# Description: Cache gh binary path from nix after build or shell probe.
# Arguments:
# - out_path: <String> nix store path for nixpkgs#gh (optional)
# Returns:
# - <Bool> 0 when NDS_GIT_GH_BIN is set
_git_gh_cache_bin_from_nix() {
    local out_path="${1:-}"
    local gh_path

    if [[ -n "$out_path" && -x "${out_path}/bin/gh" ]]; then
        NDS_GIT_GH_BIN="${out_path}/bin/gh"
        export NDS_GIT_GH_BIN
        return 0
    fi
    # Strip noise; last line should be the store path from `command -v`.
    gh_path=$(_git_gh_nix shell nixpkgs#gh -c command -v gh 2>/dev/null | tail -1) || gh_path=""
    if [[ -n "$gh_path" && -x "$gh_path" ]]; then
        NDS_GIT_GH_BIN="$gh_path"
        export NDS_GIT_GH_BIN
        return 0
    fi
    return 1
}

# Description: Build gh via nix once and cache the binary path (avoids nix shell per call).
# Reuses /tmp/nds-gh-bin across NDS restarts on the same live ISO boot.
# Returns:
# - <Bool> 0 when gh can be invoked after prefetch
nds_git_gh_prefetch() {
    if command -v gh &>/dev/null; then
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GIT_GH_PREFETCH_DONE
        return 0
    fi
    if [[ -n "${NDS_GIT_GH_BIN:-}" && -x "${NDS_GIT_GH_BIN}" ]]; then
        _git_gh_persist_bin_cache
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GIT_GH_PREFETCH_DONE
        return 0
    fi
    # Reuse store path from a prior NDS run on this ISO (no re-download spinner).
    if _git_gh_restore_bin_cache; then
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GIT_GH_PREFETCH_DONE
        if declare -f nds_step_start &>/dev/null; then
            nds_step_start "GitHub CLI (gh)"
            nds_step_complete "GitHub CLI ready (cached)"
        fi
        nds_install_log "git: gh CLI restored from cache (${NDS_GIT_GH_BIN})"
        return 0
    fi
    if ! command -v nix &>/dev/null; then
        return 1
    fi
    # Stale "done" without a binary — clear and rebuild.
    unset NDS_GIT_GH_PREFETCH_DONE 2>/dev/null || true

    if [[ "${NDS_GIT_GH_PREFETCH_IN_PROGRESS:-}" == "true" ]]; then
        return 1
    fi
    NDS_GIT_GH_PREFETCH_IN_PROGRESS=true

    local out_path build_out rc=0 logfile="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local prefetch_log="${NDS_RUNTIME_DIR:-/tmp/nds}/gh_prefetch.out"
    if declare -f nds_step_start &>/dev/null; then
        nds_step_start "Downloading GitHub CLI (gh)"
        mkdir -p "$(dirname "$prefetch_log")"
        (
            _git_gh_nix build --no-link --print-out-paths nixpkgs#gh
        ) >"$prefetch_log" 2>&1 &
        local pid=$!
        if declare -f nds_step_spinner &>/dev/null; then
            nds_step_spinner "$pid" "Downloading GitHub CLI (gh)"
        fi
        wait "$pid" || rc=$?
        build_out=$(<"$prefetch_log")
        {
            printf '\n=== Downloading GitHub CLI (gh) ===\n'
            printf '%s\n' "$build_out"
        } >>"$logfile"
    else
        info "Downloading GitHub CLI (gh) — one-time download..."
        build_out=$(_git_gh_nix build --no-link --print-out-paths nixpkgs#gh 2>&1) || rc=$?
        {
            printf '\n=== Downloading GitHub CLI (gh) ===\n'
            printf '%s\n' "$build_out"
        } >>"$logfile"
    fi
    out_path=$(printf '%s\n' "$build_out" | tail -1)
    if [[ "$rc" -ne 0 ]]; then
        unset NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
        declare -f nds_step_fail &>/dev/null && nds_step_fail "Downloading GitHub CLI (gh)"
        debug "gh prefetch failed"
        return 1
    fi
    if _git_gh_cache_bin_from_nix "$out_path"; then
        unset NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
        _git_gh_persist_bin_cache
        declare -f nds_step_complete &>/dev/null && nds_step_complete "Downloading GitHub CLI (gh)"
        NDS_GIT_GH_PREFETCH_DONE=true
        export NDS_GIT_GH_PREFETCH_DONE
        nds_install_log "git: gh CLI ready (${NDS_GIT_GH_BIN})"
        return 0
    fi
    unset NDS_GIT_GH_PREFETCH_IN_PROGRESS 2>/dev/null || true
    declare -f nds_step_fail &>/dev/null && nds_step_fail "Downloading GitHub CLI (gh)"
    debug "gh prefetch failed"
    return 1
}

# Description: Ensure a real gh binary is ready (PATH or NDS_GIT_GH_BIN).
# Returns:
# - <Bool> 0 when gh can be invoked without nix shell
nds_git_gh_ensure_prefetch() {
    nds_git_gh_bin_ready && return 0
    nds_git_gh_prefetch
}

# Description: True when gh is logged in with scopes needed for key registration.
nds_git_gh_session_ready() {
    nds_git_gh_session_active && nds_git_gh_has_key_scope
}

# Description: Clear env tokens that block interactive gh login.
nds_git_gh_unset_blocking_tokens() {
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        warn "GITHUB_TOKEN is set — clearing for gh device login (invalid tokens cause 401 errors)"
        unset GITHUB_TOKEN
    fi
    if [[ -n "${GH_TOKEN:-}" ]]; then
        warn "GH_TOKEN is set — clearing for gh device login"
        unset GH_TOKEN
    fi
}

# Description: Run a gh subcommand with optional install-step spinner.
# Arguments:
# - label: <String> Step label when nds_step_exec is available
# - gh:    <String...> gh arguments (after gh binary)
nds_git_gh_run_step() {
    local label="$1"
    shift
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 1
    if declare -f nds_step_exec &>/dev/null; then
        nds_step_exec "$label" "${gh_cmd[@]}" "$@"
    else
        info "$label..."
        "${gh_cmd[@]}" "$@"
    fi
}
