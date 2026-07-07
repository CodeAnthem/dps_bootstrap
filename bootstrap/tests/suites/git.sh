#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git tools tests (read-only / temp dirs)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-07
# ==================================================================================================

suite_git() {
    local parsed host owner repo urls tmpdir key_src dest out perms repos register_url

    parsed=$(_nds_git_parse "https://github.com/CodeAnthem/dps_swarm.git")
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    if [[ "$host" == "github.com" && "$owner" == "CodeAnthem" && "$repo" == "dps_swarm" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_parse: https github URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_parse: https github URL"
    fi

    out=$(_nds_git_ssh_url "https://github.com/org/repo.git")
    if [[ "$out" == "git@github.com:org/repo.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_ssh_url: normalizes HTTPS to SSH"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_ssh_url: expected git@github.com:org/repo.git got $out"
    fi

    out=$(_nds_git_ssh_url "ssh://git@github.com/org/thundercast.git")
    if [[ "$out" == "git@github.com:org/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_ssh_url: normalizes ssh:// to git@"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_ssh_url: ssh:// normalize got $out"
    fi

    out=$(_nds_git_ssh_url "git+ssh://git@github.com/org/thundercast.git")
    if [[ "$out" == "git@github.com:org/thundercast.git" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ _nds_git_ssh_url: normalizes git+ssh:// to git@"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ _nds_git_ssh_url: git+ssh:// normalize got $out"
    fi

    tmpdir=$(mktemp -d)
    urls=$(_nds_flake_collect_git_remote_urls "$tmpdir" "git@github.com:org/root.git")
    if grep -q 'git@github.com:org/root.git' <<<"$urls"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ closure collect: includes root URL"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ closure collect: root URL missing"
    fi

    cp "${TEST_ROOT}/fixtures/flake.lock.sample" "${tmpdir}/flake.lock"
    urls=$(_nds_flake_collect_git_remote_urls "$tmpdir" "")
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
    urls=$(_nds_flake_lock_ssh_urls "${tmpdir}/flake.lock.ssh")
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
    if [[ "$(nds_git_owner_slug)" == "codeanthem" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ owner_slug: from FLAKE_REPO_URL"
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

    if declare -f nds_git_repo_key_map_set &>/dev/null; then
        id_tmp=$(mktemp -d)
        export NDS_RUNTIME_DIR="${id_tmp}/nds-runtime"
        export NDS_GIT_DEPLOY_KEYS_DIR="${id_tmp}/ssh"
        mkdir -p "$NDS_RUNTIME_DIR" "$NDS_GIT_DEPLOY_KEYS_DIR"
        nds_git_deploy_key_generate CodeAnthem thundercast || true
        if grep -q $'CodeAnthem\tthundercast\t' "$(nds_git_repo_key_map_file)" 2>/dev/null \
            && [[ -x "$(nds_git_ssh_wrapper_path)" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ repo_key_map: deploy key mapped for nix/git wrapper"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ repo_key_map: missing map entry or git-ssh wrapper"
        fi
        unset NDS_RUNTIME_DIR NDS_GIT_DEPLOY_KEYS_DIR
        rm -rf "$id_tmp"
    fi

    if declare -f _nds_git_identity_for_url &>/dev/null; then
        local id_tmp id_key
        id_tmp=$(mktemp -d)
        export NDS_RUNTIME_DIR="${id_tmp}/nds-runtime"
        export NDS_GIT_DEPLOY_KEYS_DIR="${id_tmp}/ssh"
        mkdir -p "$NDS_RUNTIME_DIR" "$NDS_GIT_DEPLOY_KEYS_DIR"
        id_key="$(nds_git_deploy_key_path CodeAnthem thundercast)"
        ssh-keygen -t ed25519 -N "" -f "$id_key" -C test >/dev/null 2>&1 || true
        nds_git_keys_register "$id_key" || true
        key=$(_nds_git_identity_for_url "git@github.com:CodeAnthem/thundercast.git" 2>/dev/null || true)
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

    export NDS_GIT_SESSION_KEY_PATH="${tmpdir}/gen_key"
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

    mkdir -p "${tmpdir}/mnt/etc/nixos/secrets"
    nds_git_keys_register "$NDS_GIT_SESSION_KEY_PATH" || true
    if nds_git_install_keys_to_target "${tmpdir}/mnt" \
        && [[ -f "${tmpdir}/mnt/etc/nixos/secrets/$(basename "$NDS_GIT_SESSION_KEY_PATH")" ]]; then
        perms=$(stat -c '%a' "${tmpdir}/mnt/etc/nixos/secrets/$(basename "$NDS_GIT_SESSION_KEY_PATH")" 2>/dev/null || echo "")
        if [[ "$perms" == "600" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ SSH keys installed on target"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ SSH key target permissions (got ${perms})"
        fi
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ SSH keys install on target"
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
    rm -rf "$tmpdir"
}
