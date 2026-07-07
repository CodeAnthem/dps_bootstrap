#!/usr/bin/env bash
# ==================================================================================================
# NDS - GitHub CLI session helpers (logic)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

# Description: Nix CLI prefix for gh on live ISO (flakes required).
_nds_git_gh_nix() {
    nix --extra-experimental-features "nix-command flakes" "$@"
}

# Description: Resolve gh command (host binary or nix build cache).
# Arguments:
# - out: <Nameref> Command prefix array
# Returns:
# - <Bool> 0 when gh is available
nds_git_gh_cmd() {
    local -n _out=$1
    if command -v gh &>/dev/null; then
        _out=(gh)
        return 0
    fi
    if [[ -n "${NDS_GIT_GH_BIN:-}" && -x "${NDS_GIT_GH_BIN}" ]]; then
        _out=("${NDS_GIT_GH_BIN}")
        return 0
    fi
    if command -v nix &>/dev/null; then
        _out=(_nds_git_gh_nix shell nixpkgs#gh -c gh)
        return 0
    fi
    _out=()
    return 1
}

# Description: True when gh is logged in to github.com.
nds_git_gh_session_active() {
    local -a gh_cmd=()
    nds_git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" auth status &>/dev/null
}

# Description: True when token has admin:public_key scope.
nds_git_gh_has_key_scope() {
    local -a gh_cmd=()
    nds_git_gh_cmd gh_cmd || return 1
    "${gh_cmd[@]}" auth status --show-token-scopes 2>/dev/null | grep -qF 'admin:public_key'
}

# Description: End temporary gh auth on the live ISO (SSH keys on GitHub are kept).
nds_git_gh_session_cleanup() {
    local -a gh_cmd=()

    nds_git_gh_cmd gh_cmd || return 0
    if "${gh_cmd[@]}" auth status &>/dev/null; then
        "${gh_cmd[@]}" auth logout --hostname github.com 2>/dev/null || true
        nds_install_log "git: gh session cleared from live ISO (SSH key left on GitHub)"
    fi
}

# Description: True when gh CLI is available on the live ISO.
nds_git_gh_available() {
    local -a gh_cmd=()
    nds_git_gh_cmd gh_cmd
}

# Description: Build gh via nix once and cache the binary path (avoids nix shell per call).
# Returns:
# - <Bool> 0 when gh can be invoked after prefetch
nds_git_gh_prefetch() {
    if command -v gh &>/dev/null; then
        return 0
    fi
    if ! command -v nix &>/dev/null; then
        return 1
    fi
    if [[ -n "${NDS_GIT_GH_BIN:-}" && -x "${NDS_GIT_GH_BIN}" ]]; then
        return 0
    fi
    local out_path err
    if declare -f step_start &>/dev/null; then
        step_start "Downloading GitHub CLI (gh)"
    else
        info "Downloading GitHub CLI (gh) — one-time download..."
    fi
    err=$(_nds_git_gh_nix build --no-link --print-out-paths nixpkgs#gh 2>&1) || true
    out_path=$(printf '%s\n' "$err" | tail -1)
    if [[ -n "$out_path" && -x "${out_path}/bin/gh" ]]; then
        declare -f step_complete &>/dev/null && step_complete "Downloading GitHub CLI (gh)"
        NDS_GIT_GH_BIN="${out_path}/bin/gh"
        export NDS_GIT_GH_BIN
        return 0
    fi
    if _nds_git_gh_nix shell nixpkgs#gh -c gh --version &>/dev/null; then
        declare -f step_complete &>/dev/null && step_complete "Downloading GitHub CLI (gh)"
        debug "gh via nix shell (build cache unavailable): ${err}"
        return 0
    fi
    declare -f step_fail &>/dev/null && step_fail "Downloading GitHub CLI (gh)"
    debug "gh prefetch failed: ${err}"
    return 1
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
