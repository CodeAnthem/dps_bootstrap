#!/usr/bin/env bash
# ==================================================================================================
# NDS - Installer secrets
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-30
# Description:   Locate runtime secret files (LUKS keys) for inclusion in the backup bundle
# ==================================================================================================

# Description: List secret files produced during this install run.
# Returns:
# - <String> One absolute path per line (runtime secrets + LUKS key candidates)
nds_secrets_list_runtime() {
    local item

    if [[ -d "${NDS_RUNTIME_DIR:-}/secrets" ]]; then
        for item in "${NDS_RUNTIME_DIR}/secrets"/*; do
            [[ -f "$item" ]] && echo "$item"
        done
    fi

    if [[ -n "${NDS_KEY_FILE:-}" && -f "$NDS_KEY_FILE" ]]; then
        echo "$NDS_KEY_FILE"
    fi

    if [[ -f /tmp/luks_key.txt ]]; then
        echo "/tmp/luks_key.txt"
    fi
}
