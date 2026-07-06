#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git tools tests (read-only / temp dirs)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-07-05
# ==================================================================================================

suite_git() {
    local parsed host owner repo urls tmpdir key_src dest out perms repos

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
    rm -rf "$tmpdir"

    repos=$(_nds_git_urls_to_github_repos \
        "git@github.com:org/a.git" "git@gitlab.com:other/b.git")
    if [[ "$(wc -l <<<"$repos")" -eq 1 ]] && grep -q 'org/a' <<<"$repos"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ gh repo list: github.com only"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ gh repo list: expected single github repo"
    fi

    if declare -f nds_git_auth_prompt_method &>/dev/null \
        && declare -f nds_git_auth_screen_single &>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ git auth wizard: prompt and screen functions loaded"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ git auth wizard: prompt/screen functions missing"
    fi

    CONFIG_DATA[FLAKE_HOST]="control-toolkit"
    if [[ "$(nds_git_deploy_key_title)" == "nds-control-toolkit" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ deploy_key_title: uses FLAKE_HOST"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ deploy_key_title: expected nds-control-toolkit"
    fi

    if declare -f nds_git_auth_resolve_key_display &>/dev/null; then
        export NDS_GIT_DEPLOY_KEY_DISPLAY=qr
        if [[ "$(nds_git_auth_resolve_key_display)" == "qr" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ resolve_key_display: NDS_GIT_DEPLOY_KEY_DISPLAY=qr"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ resolve_key_display: expected qr from env"
        fi
        unset NDS_GIT_DEPLOY_KEY_DISPLAY
    fi

    tmpdir=$(mktemp -d)
    key_src="${tmpdir}/source_key"
    dest="${tmpdir}/session/id_ed25519"
    ssh-keygen -t ed25519 -N "" -f "$key_src" -C test >/dev/null 2>&1
    export NDS_DEPLOY_KEY_PATH="$key_src"
    export NDS_GIT_SESSION_KEY_PATH="$dest"
    if nds_git_auth_try_deploy_key_path && [[ -f "$dest" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ deploy key import via NDS_DEPLOY_KEY_PATH"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ deploy key import via NDS_DEPLOY_KEY_PATH"
    fi
    unset NDS_DEPLOY_KEY_PATH NDS_GIT_SESSION_KEY_PATH

    export NDS_GIT_SESSION_KEY_PATH="${tmpdir}/gen_key"
    if nds_git_key_generate "$NDS_GIT_SESSION_KEY_PATH" "test-gen" \
        && [[ -f "${NDS_GIT_SESSION_KEY_PATH}.pub" ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ nds_git_key_generate"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ nds_git_key_generate"
    fi

    mkdir -p "${tmpdir}/mnt/etc/nixos/secrets"
    if nds_git_install_deploy_key_to_target "$NDS_GIT_SESSION_KEY_PATH" "${tmpdir}/mnt" \
        && [[ -f "${tmpdir}/mnt/etc/nixos/secrets/git-deploy-key" ]]; then
        perms=$(stat -c '%a' "${tmpdir}/mnt/etc/nixos/secrets/git-deploy-key" 2>/dev/null || echo "")
        if [[ "$perms" == "600" ]]; then
            TEST_PASSED=$((TEST_PASSED + 1))
            console "  ✓ deploy key installed on target (mode 600)"
        else
            TEST_FAILED=$((TEST_FAILED + 1))
            console "  ✗ deploy key target permissions (got ${perms})"
        fi
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ deploy key install on target"
    fi
    unset NDS_GIT_SESSION_KEY_PATH
    rm -rf "$tmpdir"
}
