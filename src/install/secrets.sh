#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-01
# Description:   Locate runtime secret files for inclusion in the backup bundle
# Feature:       Collects luks_password.txt, luks_key.bin, initrd SSH host keys
# ==================================================================================================

# Description: List secret files produced during this install run.
# Returns:
# - <String> One absolute path per line (everything in the runtime secrets dir)
nds_secrets_list_runtime() {
    local item

    if [[ -d "${NDS_RUNTIME_DIR:-}/secrets" ]]; then
        for item in "${NDS_RUNTIME_DIR}/secrets"/*; do
            [[ -f "$item" ]] && echo "$item"
        done
    fi
}
