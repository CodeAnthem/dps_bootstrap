#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard screens (menu output)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-07-07
# ==================================================================================================

declare -ga NDS_GIT_AUTH_REGISTER_URLS=()

# Description: Short intro — one SSH key, account registration.
nds_git_wizard_screen_intro() {
    section_header "Private repository access"
    nds_ui_b "Private flakes need SSH git access. NDS checks every git input"
    nds_ui_b "(your flake URL plus locked inputs in flake.lock)."
    nds_ui_b ""
    nds_ui_b "One SSH key for this session — import an existing key, let gh add a"
    nds_ui_b "read-only account key (GitHub only), or register manually."
    nds_ui_b ""
}

# Description: Print one repo line with optional status marker.
# Arguments:
# - url:    <String> Git remote URL
# - status: <String|optional> ok, missing, or empty
nds_git_wizard_print_repo() {
    local url="$1"
    local status="${2:-}"
    local ssh_url parsed host owner repo register_url

    ssh_url=$(_nds_git_ssh_url "$url")
    if parsed=$(_nds_git_parse "$ssh_url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$status" == "ok" ]]; then
            nds_ui_i "  [ok]  ${owner}/${repo}"
        elif [[ "$status" == "missing" ]]; then
            nds_ui_i "  [!!]  ${owner}/${repo}"
        else
            nds_ui_i "  ${owner}/${repo}"
        fi
        register_url="$(nds_git_account_ssh_register_url "$host")"
        nds_ui_i "        ${register_url}"
    else
        nds_ui_i "  ${ssh_url}"
    fi
}

# Description: Collect account SSH registration URLs for manual path.
# Arguments:
# - urls: <String...> Git remote URLs
nds_git_wizard_collect_register_urls() {
    local url parsed host owner repo register_url
    NDS_GIT_AUTH_REGISTER_URLS=()
    for url in "$@"; do
        url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        register_url="$(nds_git_account_ssh_register_url "$host")"
        [[ "$register_url" == http* ]] && NDS_GIT_AUTH_REGISTER_URLS+=("$register_url")
    done
}

# Description: List repositories with access status (closure check).
# Arguments:
# - urls_var:   <Nameref> All URLs checked
# - failed_var: <Nameref> URLs that failed probe
nds_git_wizard_screen_list_repos() {
    local -n _urls=$1
    local -n _failed=$2
    local url ssh_url parsed host owner repo key
    declare -A repo_status=() repo_sample=()

    nds_ui_h "Repositories"
    for url in "${_urls[@]}"; do
        ssh_url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        key="${owner}/${repo}"
        repo_sample[$key]="$url"
        [[ -z "${repo_status[$key]:-}" ]] && repo_status[$key]="ok"
    done
    for url in "${_failed[@]}"; do
        ssh_url=$(_nds_git_ssh_url "$url")
        parsed=$(_nds_git_parse "$ssh_url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        repo_status["${owner}/${repo}"]="missing"
        [[ -z "${repo_sample[${owner}/${repo}]:-}" ]] && repo_sample["${owner}/${repo}"]="$url"
    done
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        nds_git_wizard_print_repo "${repo_sample[$key]}" "${repo_status[$key]}"
    done < <(printf '%s\n' "${!repo_status[@]}" | sort)
    nds_ui_b ""
}

# Description: Screen for a single root flake repo.
# Arguments:
# - host:  <String> Git host
# - owner: <String> Repo owner
# - repo:  <String> Repo name
nds_git_wizard_screen_single() {
    local host="$1" owner="$2" repo="$3"

    nds_git_wizard_screen_intro
    nds_git_wizard_collect_register_urls "$(_nds_git_to_ssh "$host" "$owner" "$repo")"
    nds_ui_h "Repository"
    nds_git_wizard_print_repo "$(_nds_git_to_ssh "$host" "$owner" "$repo")" "missing"
    nds_ui_b ""
}

# Description: Screen when flake.lock inputs lack access.
# Arguments:
# - failed: <String...> URLs that failed probe
nds_git_wizard_screen_closure() {
    local -a failed=("$@")
    local -a all_urls=()
    local url

    nds_git_wizard_screen_intro
    nds_git_wizard_collect_register_urls "${failed[@]}"

    if [[ -n "${NDS_GIT_CLOSURE_URLS:-}" ]]; then
        readarray -t all_urls <<< "$NDS_GIT_CLOSURE_URLS"
    else
        all_urls=("${failed[@]}")
    fi

    if [[ ${#all_urls[@]} -gt 0 && ${#failed[@]} -lt ${#all_urls[@]} ]]; then
        nds_git_wizard_screen_list_repos all_urls failed
    else
        nds_ui_h "Repositories missing access"
        declare -A _missing_printed=()
        local ssh_url parsed host owner repo mkey
        for url in "${failed[@]}"; do
            ssh_url=$(_nds_git_ssh_url "$url")
            parsed=$(_nds_git_parse "$ssh_url") || continue
            IFS=$'\t' read -r host owner repo <<< "$parsed"
            mkey="${owner}/${repo}"
            [[ -n "${_missing_printed[$mkey]:-}" ]] && continue
            _missing_printed[$mkey]=1
            nds_git_wizard_print_repo "$url" "missing"
        done
        nds_ui_b ""
    fi
}
