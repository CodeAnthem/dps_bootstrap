#!/usr/bin/env bash
# ==================================================================================================
# NDS - Encryption secret prompts (/dev/tty — runs under nds_step_exec)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-05
# Description:   Interactive LUKS password / keyfile path collection only
# ==================================================================================================

# Description: Prompt for LUKS passphrase on /dev/tty; print passphrase to stdout.
nds_encryption_prompts_password() {
    local pw1="" pw2="" confirm
    while true; do
        printf 'Enter LUKS password: ' > /dev/tty
        read -rs pw1 < /dev/tty; printf '\n' > /dev/tty
        printf 'Confirm LUKS password: ' > /dev/tty
        read -rs pw2 < /dev/tty; printf '\n' > /dev/tty
        if [[ -z "$pw1" ]]; then
            printf 'Password cannot be empty — try again.\n' > /dev/tty; continue
        fi
        if [[ "$pw1" != "$pw2" ]]; then
            printf 'Passwords do not match — try again.\n' > /dev/tty; continue
        fi
        if [[ ${#pw1} -lt 12 ]]; then
            printf 'Password is short (%s chars) — consider a longer one.\n' "${#pw1}" > /dev/tty
            printf 'Use this password anyway? [y/N]: ' > /dev/tty
            read -r confirm < /dev/tty
            [[ "${confirm,,}" == "y" ]] || continue
        fi
        break
    done
    printf '%s' "$pw1"
}

# Description: Prompt for existing keyfile path on /dev/tty; print path to stdout.
nds_encryption_prompts_keyfile_path() {
    local src_path
    while true; do
        printf 'Enter path to existing keyfile on the live system: ' > /dev/tty
        read -r src_path < /dev/tty
        if [[ -n "$src_path" && -f "$src_path" ]]; then
            printf '%s' "$src_path"
            return 0
        fi
        printf 'File not found: %s — try again.\n' "$src_path" > /dev/tty
    done
}
