#!/usr/bin/env bash
# ==================================================================================================
# NDS - /dev/urandom helpers (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   openssl-free random string generation for live ISO
# ==================================================================================================

# Description: Generate N random alphanumeric characters from /dev/urandom.
# Arguments:
# - count: <String> Number of characters
# Returns:
# - <String> random string on stdout
nds_install_urandom_chars() {
    local n="$1"
    local raw
    raw=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c "$(( n * 8 + 128 ))" /dev/urandom))
    printf '%s' "${raw:0:n}"
}
