#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git UI: leftover session / access hints
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================

# Description: Blank line then ask whether to clear leftover gh session (existing ask).
nds_git_ui_offer_clear_gh_session() {
    nds_ui_b ""
    nds_git_ui_ask_clear_gh_session
}

# Description: Show deploy-key registration URL hint for a GitHub repo.
# Arguments:
# - owner: <String>
# - repo:  <String>
nds_git_ui_deploy_key_hint() {
    local owner="$1" repo="$2"
    nds_ui_i "Deploy keys: https://github.com/${owner}/${repo}/settings/keys"
}
