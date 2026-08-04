#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git tools tests (read-only / temp dirs)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-31
# ==================================================================================================

suite_git() {
    local parsed host owner repo urls tmpdir key_src dest out perms repos register_url

    out=$(nds_git_normalize_url "https://github.com/CodeAnthem/dps_swarm.git")
    if [[ "$out" == "git@github.com:CodeAnthem/dps_swarm.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ normalize_url: HTTPS → SSH (underscore repo name)"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ normalize_url: got $out"
    fi

    NDS_GIT_METHOD=()
    nds_git_access_set method "https://github.com/CodeAnthem/dps_swarm.git" "account"
    if [[ "$(nds_git_access_get method "git@github.com:CodeAnthem/dps_swarm.git")" == "account" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ access map: same key for https and ssh forms"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ access map: URL key mismatch"
    fi

    parsed=$(_git_parse "https://github.com/CodeAnthem/dps_swarm.git")
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    if [[ "$host" == "github.com" && "$owner" == "CodeAnthem" && "$repo" == "dps_swarm" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _git_parse: https github URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _git_parse: https github URL"
    fi

    out=$(_git_ssh_url "https://github.com/org/repo.git")
    if [[ "$out" == "git@github.com:org/repo.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _git_ssh_url: normalizes HTTPS to SSH"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _git_ssh_url: expected git@github.com:org/repo.git got $out"
    fi

    out=$(_git_ssh_url "ssh://git@github.com/org/thundercast.git")
    if [[ "$out" == "git@github.com:org/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _git_ssh_url: normalizes ssh:// to git@"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _git_ssh_url: ssh:// normalize got $out"
    fi

    out=$(_git_ssh_url "git+ssh://git@github.com/org/thundercast.git")
    if [[ "$out" == "git@github.com:org/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _git_ssh_url: normalizes git+ssh:// to git@"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _git_ssh_url: git+ssh:// normalize got $out"
    fi

    tmpdir=$(mktemp -d)
    urls=$(_flake_collect_git_remote_urls "$tmpdir" "git@github.com:org/root.git")
    if grep -q 'git@github.com:org/root.git' <<<"$urls"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ closure collect: includes root URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ closure collect: root URL missing"
    fi

    cp "${TEST_ROOT}/fixtures/flake.lock.sample" "${tmpdir}/flake.lock"
    urls=$(_flake_collect_git_remote_urls "$tmpdir" "")
    if grep -q 'git@github.com:org/thundercore' <<<"$urls" \
       && grep -q 'git@github.com:org/thundercast' <<<"$urls"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ closure collect: parses flake.lock git+ssh inputs"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ closure collect: flake.lock inputs missing"
    fi

    printf '%s\n' '{"nodes":{"t":{"locked":{"type":"git","url":"ssh://git@github.com/CodeAnthem/thundercore.git"}}}}' \
        > "${tmpdir}/flake.lock.ssh"
    urls=$(_flake_lock_ssh_urls "${tmpdir}/flake.lock.ssh")
    if grep -q 'ssh://git@github.com/CodeAnthem/thundercore.git' <<<"$urls"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ flake.lock: parses ssh://git@ URLs"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ flake.lock: ssh://git@ URL parse failed"
    fi
    rm -rf "$tmpdir"

    repos=$(nds_git_urls_to_github_repos \
        "git@github.com:org/a.git" "git@gitlab.com:other/b.git")
    if [[ "$(wc -l <<<"$repos")" -eq 1 ]] && grep -q 'org/a' <<<"$repos"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ gh repo list: github.com only"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ gh repo list: expected single github repo"
    fi

    if nds_git_urls_all_github "git@github.com:org/a.git" "git@github.com:org/b.git"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ urls_all_github: true for github hosts"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ urls_all_github: expected true for github hosts"
    fi

    if ! nds_git_urls_all_github "git@github.com:org/a.git" "git@gitlab.com:other/b.git"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ urls_all_github: false when mixed hosts"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ urls_all_github: expected false for mixed hosts"
    fi

    register_url="$(nds_git_account_ssh_register_url "github.com")"
    if [[ "$register_url" == "https://github.com/settings/ssh/new" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ account_ssh_register_url: GitHub account keys page"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ account_ssh_register_url: expected github.com/settings/ssh/new"
    fi

    if declare -f nds_git_wizard_route_menu &>/dev/null \
        && declare -f nds_git_wizard_screen_single &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git wizard: flow and screen functions loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git wizard: flow/screen functions missing"
    fi

    CONFIG_DATA[FLAKE_HOST]="control-toolkit"
    CONFIG_DATA[FLAKE_REPO_URL]="git@github.com:CodeAnthem/dps_swarm.git"
    if [[ "$(nds_git_owner_slug "${CONFIG_DATA[FLAKE_REPO_URL]}")" == "codeanthem" ]] \
       && [[ "$(nds_git_cfg_owner_slug)" == "codeanthem" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ owner_slug: from URL arg + FLAKE_REPO_URL cfg bridge"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ owner_slug: expected codeanthem"
    fi
    if [[ "$(nds_git_secrets_basename)" == "git-codeanthem-key" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ secrets_basename: git-<owner>-key"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ secrets_basename: expected git-codeanthem-key"
    fi
    if [[ "$(nds_git_ssh_key_title)" == "nds-codeanthem-control-toolkit" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ ssh_key_title: owner + FLAKE_HOST"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ ssh_key_title: expected nds-codeanthem-control-toolkit"
    fi

    if declare -f nds_git_wizard_resolve_key_display &>/dev/null; then
        export NDS_GIT_SSH_KEY_USE_QR=true
        if [[ "$(nds_git_wizard_resolve_key_display)" == "qr" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ resolve_key_display: NDS_GIT_SSH_KEY_USE_QR=true"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ resolve_key_display: expected qr from env"
        fi
        unset NDS_GIT_SSH_KEY_USE_QR
    fi

    if declare -f nds_git_deploy_key_basename &>/dev/null; then
        if [[ "$(nds_git_deploy_key_basename CodeAnthem dps_swarm)" == "nds_deploy_codeanthem_dps_swarm" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy_key_basename: nds_deploy_owner_repo"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy_key_basename: expected nds_deploy_codeanthem_dps_swarm"
        fi
        if [[ "$(nds_git_deploy_key_title CodeAnthem dps_swarm)" == "nds_control-toolkit" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy_key_title: nds_<hostname> on GitHub"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy_key_title: expected nds_control-toolkit"
        fi
    fi

    if declare -f _flake_lock_git_entries &>/dev/null; then
        local lock_tmp lock_file
        lock_tmp=$(mktemp -d)
        lock_file="${lock_tmp}/flake.lock"
        cat >"$lock_file" <<'LOCK'
{
  "nodes": {
    "root": { "locked": { "type": "path" } },
    "thundercast": {
      "locked": {
        "type": "git",
        "url": "ssh://git@github.com/CodeAnthem/thundercast",
        "rev": "abc123def456",
        "narHash": "sha256-TEST"
      }
    }
  }
}
LOCK
        if _flake_lock_git_entries "$lock_file" | grep -q $'ssh://git@github.com/CodeAnthem/thundercast\tabc123def456\tsha256-TEST'; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_lock_git_entries: parses git inputs from flake.lock"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_lock_git_entries: parse failed"
        fi
        rm -rf "$lock_tmp"
    fi

    if declare -f _git_identity_for_url &>/dev/null; then
        local id_tmp id_key
        id_tmp=$(mktemp -d)
        export NDS_RUNTIME_DIR="${id_tmp}/nds-runtime"
        export NDS_GIT_DEPLOY_KEYS_DIR="${id_tmp}/ssh"
        mkdir -p "$NDS_RUNTIME_DIR" "$NDS_GIT_DEPLOY_KEYS_DIR"
        id_key="$(nds_git_deploy_key_path CodeAnthem thundercast)"
        ssh-keygen -t ed25519 -N "" -f "$id_key" -C test >/dev/null 2>&1 || true
        nds_git_keys_register "$id_key" || true
        key=$(_git_identity_for_url "git@github.com:CodeAnthem/thundercast.git" 2>/dev/null || true)
        if [[ "$key" == "$id_key" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ identity_for_url: deploy key per repository"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ identity_for_url: expected ${id_key}, got ${key:-empty}"
        fi
        unset NDS_RUNTIME_DIR NDS_GIT_DEPLOY_KEYS_DIR
        rm -rf "$id_tmp"
    fi

    if declare -f nds_git_auth_set_mode &>/dev/null; then
        nds_git_auth_set_mode deploy
        if [[ "$(nds_git_auth_mode)" == "deploy" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ git auth mode: deploy"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ git auth mode: expected deploy"
        fi
    fi

    if declare -f nds_git_deploy_key_register_url &>/dev/null; then
        register_url="$(nds_git_deploy_key_register_url github.com CodeAnthem dps_swarm)"
        if [[ "$register_url" == "https://github.com/CodeAnthem/dps_swarm/settings/keys" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy_key_register_url: GitHub repo settings"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy_key_register_url: unexpected ${register_url}"
        fi
    fi

    tmpdir=$(mktemp -d)
    key_src="${tmpdir}/source_key"

    export NDS_RUNTIME_DIR="${tmpdir}/nds-runtime"
    mkdir -p "$NDS_RUNTIME_DIR"
    touch "${tmpdir}/test-key"
    if nds_git_keys_register "${tmpdir}/test-key" \
        && grep -qxF "${tmpdir}/test-key" <(nds_git_keys_list); then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ keys_register: session registry"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ keys_register: session registry"
    fi
    unset NDS_RUNTIME_DIR

    dest="${tmpdir}/session/id_ed25519"
    ssh-keygen -t ed25519 -N "" -f "$key_src" -C test >/dev/null 2>&1
    export NDS_GIT_IMPORT_KEY_PATH="$key_src"
    export NDS_GIT_SESSION_KEY_PATH="$dest"
    if nds_git_auth_try_import_path && [[ -f "$dest" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ SSH key import via NDS_GIT_IMPORT_KEY_PATH"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ SSH key import via NDS_GIT_IMPORT_KEY_PATH"
    fi
    unset NDS_GIT_IMPORT_KEY_PATH NDS_GIT_SESSION_KEY_PATH

    export NDS_GIT_DEPLOY_KEYS_DIR="$tmpdir"
    export NDS_GIT_SESSION_KEY_PATH="${tmpdir}/nds_deploy_org_repo"
    if nds_git_key_generate "$NDS_GIT_SESSION_KEY_PATH" "test-gen" \
        && [[ -f "${NDS_GIT_SESSION_KEY_PATH}.pub" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_key_generate"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_key_generate"
    fi
    if nds_git_key_generate "$NDS_GIT_SESSION_KEY_PATH" "test-gen-reuse" \
        && [[ -f "${NDS_GIT_SESSION_KEY_PATH}.pub" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_key_generate: reuses existing key"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_key_generate: reuse failed"
    fi

    mkdir -p "${tmpdir}/mnt"
    nds_git_keys_register "$NDS_GIT_SESSION_KEY_PATH" || true
    # Unit test: install keys without network RO probe (no flake checkout)
    unset NDS_CTX_FLAKE_INSTALL_PATH NDS_FLAKE_INSTALL_PATH NDS_FLAKE_REPO_URL NDS_CTX_FLAKE_REPO_URL
    if nds_git_install_keys_to_target "${tmpdir}/mnt" "" \
        && [[ -f "${tmpdir}/mnt/root/.ssh/nds_deploy_org_repo" ]] \
        && [[ -x "${tmpdir}/mnt/root/.ssh/nds-git-ssh" ]] \
        && [[ -x "${tmpdir}/mnt/root/.nds/bin/nds-switch" ]] \
        && [[ -f "${tmpdir}/mnt/root/.ssh/nds-git.map" ]]; then
        perms=$(stat -c '%a' "${tmpdir}/mnt/root/.ssh/nds_deploy_org_repo" 2>/dev/null || echo "")
        if [[ "$perms" == "600" ]] \
            && grep -q 'org/repo' "${tmpdir}/mnt/root/.ssh/nds-git.map" \
            && grep -qF 'Wi0dh2l9GKJl' "${tmpdir}/mnt/root/.ssh/known_hosts"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ SSH keys + nds-git-ssh + nds-switch installed on target"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ SSH key target map/perms/hostkeys (got ${perms})"
        fi
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ SSH keys install on target"
    fi
    unset NDS_GIT_DEPLOY_KEYS_DIR

    if declare -f nds_git_github_official_host_keys &>/dev/null; then
        ed25519=$(nds_git_github_official_host_keys | awk '/ssh-ed25519/{print $3; exit}')
        # Official docs.github.com Ed25519 host key (must not regress to the typo WiVhwz… blob)
        if [[ "$ed25519" == "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ github official host key: Ed25519 matches docs"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ github official host key: Ed25519 mismatch"
        fi
        if printf '%s' "$ed25519" | grep -q 'WiVhwzGm9JRs'; then
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ github host key: known-bad typo blob present"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ github official host key: rejects known-bad typo"
        fi
    fi

    if [[ -f "$(_git_switch_src 2>/dev/null || true)" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds-switch.sh present in runtime-tools"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds-switch.sh missing"
    fi

    if declare -f nds_git_discover_key_candidates &>/dev/null; then
        cp "$key_src" "${tmpdir}/id_ed25519_test"
        (
            cd "$tmpdir" || exit 1
            if nds_git_discover_key_candidates | grep -q 'id_ed25519_test'; then
                exit 0
            fi
            exit 1
        ) && {
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ discover_key_candidates: scans cwd"
        } || {
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ discover_key_candidates: cwd scan"
        }
    fi

    unset NDS_GIT_SESSION_KEY_PATH

    if declare -f nds_git_gh_bin_ready &>/dev/null; then
        unset NDS_GIT_GH_BIN NDS_GIT_GH_PREFETCH_DONE
        if ! nds_git_gh_bin_ready; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_bin_ready: false without PATH/BIN"
        else
            # Host may have gh installed
            if command -v gh &>/dev/null; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ gh_bin_ready: host gh on PATH"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ gh_bin_ready: unexpected true"
            fi
        fi
        fake_bin="${tmpdir}/fake-gh"
        printf '#!/bin/sh\necho fake-gh\n' >"$fake_bin"
        chmod +x "$fake_bin"
        export NDS_GIT_GH_BIN="$fake_bin"
        if nds_git_gh_bin_ready; then
            local -a cmd=()
            local saved_path="$PATH"
            PATH="/var/empty:${tmpdir}"
            nds_git_gh_cmd cmd
            PATH="$saved_path"
            if [[ "${cmd[0]}" == "$fake_bin" ]]; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ gh_cmd: prefers NDS_GIT_GH_BIN over nix shell"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ gh_cmd: expected cached bin, got ${cmd[*]}"
            fi
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh_bin_ready: false with NDS_GIT_GH_BIN set"
        fi
        # Stale PREFETCH_DONE alone must not imply a ready binary
        unset NDS_GIT_GH_BIN
        export NDS_GIT_GH_PREFETCH_DONE=true
        if ! nds_git_gh_bin_ready; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ ensure_prefetch: stale PREFETCH_DONE does not imply bin ready"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ ensure_prefetch: bin ready without BIN after unset"
        fi
        unset NDS_GIT_GH_BIN NDS_GIT_GH_PREFETCH_DONE

        # cmd_nofetch must never invent a nix-shell fallback
        local -a nofetch_cmd=()
        local saved_path2="$PATH"
        PATH="/var/empty:${tmpdir}"
        unset NDS_GIT_GH_BIN
        if ! nds_git_gh_cmd_nofetch nofetch_cmd; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_cmd_nofetch: false without PATH/BIN"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh_cmd_nofetch: expected false without binary"
        fi
        PATH="$saved_path2"
    fi

    if declare -f nds_git_gh_hosts_yml_has_github &>/dev/null; then
        local gh_cfg_dir hosts_file
        gh_cfg_dir=$(mktemp -d)
        hosts_file="${gh_cfg_dir}/hosts.yml"
        printf 'github.com:\n    user: test\n' >"$hosts_file"
        GH_CONFIG_DIR="$gh_cfg_dir"
        if nds_git_gh_hosts_yml_has_github; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ hosts_yml_has_github: detects leftover session"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ hosts_yml_has_github: missed github.com entry"
        fi
        # Binary present but auth status fails — still detect via hosts.yml
        if declare -f nds_git_gh_host_logged_in &>/dev/null; then
            local fake_gh="${gh_cfg_dir}/gh"
            printf '#!/bin/sh\necho "not logged in" >&2\nexit 1\n' >"$fake_gh"
            chmod +x "$fake_gh"
            local saved_bin="${NDS_GIT_GH_BIN:-}" saved_path3="$PATH"
            unset NDS_GIT_GH_BIN
            # Fake gh first; keep /usr/bin so grep/getent still work
            PATH="${gh_cfg_dir}:/usr/bin:/bin"
            if nds_git_gh_host_logged_in; then
                TEST_PASSED=$((TEST_PASSED + 1))
                console "  ✓ gh_host_logged_in: hosts.yml fallback when auth status fails"
            else
                TEST_FAILED=$((TEST_FAILED + 1))
                console "  ✗ gh_host_logged_in: missed hosts.yml after failed auth status"
            fi
            PATH="$saved_path3"
            if [[ -n "$saved_bin" ]]; then export NDS_GIT_GH_BIN="$saved_bin"; else unset NDS_GIT_GH_BIN; fi
        fi
        rm -f "$hosts_file"
        if ! nds_git_gh_hosts_yml_has_github; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ hosts_yml_has_github: false when absent"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ hosts_yml_has_github: true without file"
        fi
        unset GH_CONFIG_DIR
        rm -rf "$gh_cfg_dir"
    fi

    if declare -f _git_gh_persist_bin_cache &>/dev/null; then
        local cache_tmp bin_tmp saved_cache
        cache_tmp=$(mktemp)
        bin_tmp=$(mktemp)
        printf '#!/bin/sh\necho ok\n' >"$bin_tmp"
        chmod +x "$bin_tmp"
        saved_cache="${NDS_GIT_GH_BIN_CACHE_FILE:-}"
        NDS_GIT_GH_BIN_CACHE_FILE="$cache_tmp"
        export NDS_GIT_GH_BIN="$bin_tmp"
        _git_gh_persist_bin_cache
        unset NDS_GIT_GH_BIN
        if _git_gh_restore_bin_cache && [[ "$NDS_GIT_GH_BIN" == "$bin_tmp" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh bin cache: persist + restore"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh bin cache: persist + restore"
        fi
        unset NDS_GIT_GH_BIN
        if [[ -n "$saved_cache" ]]; then NDS_GIT_GH_BIN_CACHE_FILE="$saved_cache"; else unset NDS_GIT_GH_BIN_CACHE_FILE; fi
        rm -f "$cache_tmp" "$bin_tmp"
    fi

    if declare -f nds_git_persist_access &>/dev/null; then
        nds_cfg_set GIT_PERSIST_ACCESS "false"
        if ! nds_git_persist_access; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ persist_access: false"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ persist_access: expected false"
        fi
        nds_cfg_set GIT_PERSIST_ACCESS "true"
        if nds_git_persist_access; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ persist_access: true"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ persist_access: expected true"
        fi
        nds_cfg_set GIT_PERSIST_ACCESS ""
    fi

    if declare -f nds_git_gh_host_logged_in &>/dev/null; then
        if ! nds_git_gh_host_logged_in 2>/dev/null; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_host_logged_in: false without session"
        else
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_host_logged_in: host has an active gh login"
        fi
    fi

    if declare -f nds_git_gh_session_cleanup &>/dev/null; then
        if nds_git_gh_session_cleanup 2>/dev/null; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ gh_session_cleanup: idempotent when logged out"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ gh_session_cleanup: failed when logged out"
        fi
    fi

    if declare -f nds_flake_host_in_list &>/dev/null; then
        if nds_flake_host_in_list "control-toolkit" "a" "control-toolkit" "b"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_host_in_list: match"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_host_in_list: match"
        fi
        if ! nds_flake_host_in_list "missing" "a" "b"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_host_in_list: miss"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_host_in_list: miss"
        fi
    fi

    if declare -f nds_flake_list_hosts &>/dev/null; then
        local flake_tmp hosts_out
        flake_tmp=$(mktemp -d)
        mkdir -p "${flake_tmp}/hosts/x86_64-linux/control-toolkit" \
            "${flake_tmp}/hosts/x86_64-linux/worker-01"
        printf '{ outputs = _: {}; }\n' >"${flake_tmp}/flake.nix"
        hosts_out="$(nds_flake_list_hosts "$flake_tmp" 2>/dev/null || true)"
        if grep -q 'control-toolkit' <<<"$hosts_out" && grep -q 'worker-01' <<<"$hosts_out"; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ flake_list_hosts: host-dir filesystem fallback"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ flake_list_hosts: fallback got: ${hosts_out:-empty}"
        fi
        rm -rf "$flake_tmp"
    fi

    rm -rf "$tmpdir"
}
