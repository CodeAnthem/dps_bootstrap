#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic config - LUKS unlock
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-06-30
# Description:   Wire the LUKS keyfile into the initrd for keyfile-unlock installs
# ==================================================================================================

# Auto-mode: reads from the disk configurator answers.
nds_nixcfg_luks_auto() {
    local encryption use_passphrase remote_unlock
    encryption=$(nds_config_get "disk" "ENCRYPTION")
    use_passphrase=$(nds_config_get "disk" "ENCRYPTION_USE_PASSPHRASE")
    remote_unlock=$(nds_config_get "disk" "REMOTE_UNLOCK")

    # keyFile unlock only applies to the default keyfile case.
    # Passphrase installs prompt at boot; remote unlock uses dropbear in initrd.
    [[ "$encryption" == "true" \
        && "$use_passphrase" != "true" \
        && "$remote_unlock" != "true" ]] || return 0

    local block
    block=$(cat <<'EOF'
# LUKS root unlocked via keyfile embedded in the initrd
boot.initrd.luks.devices."cryptroot".keyFile = "/etc/luks-keys/cryptroot";
EOF
)
    nds_nixcfg_register "luks" "$block" 12
}
