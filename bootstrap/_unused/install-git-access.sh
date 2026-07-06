#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access (compat loader)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-04 | Modified: 2026-07-05
# Description:   Loads bootstrap/tools/git/* (kept for install dir import order)
# ==================================================================================================

if [[ "${NDS_GIT_TOOLS_LOADED:-false}" == "true" ]]; then
    :
else
    _nds_git_tools_dir() {
        cd "$(dirname "${BASH_SOURCE[0]}")/../../tools/git" && pwd
    }
    _tools_dir="$(_nds_git_tools_dir)"
    for _git_tool in url.sh ssh.sh probe.sh closure.sh key.sh wizard.sh auth.sh; do
        # shellcheck source=/dev/null
        source "${_tools_dir}/${_git_tool}"
    done
    NDS_GIT_TOOLS_LOADED=true
    unset _tools_dir _git_tool _nds_git_tools_dir
fi
