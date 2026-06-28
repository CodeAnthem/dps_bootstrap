#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration example
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2024-10-15 | Modified: 2026-06-28
# Description:   Environment variable preset for installFlake
# ==================================================================================================
#
# Copy or source before running: sudo bash bootstrap/main.sh

# =============================================================================
# FLAKE INSTALL (installFlake action)
# =============================================================================

export NDS_FLAKE_SOURCE="remote"          # remote | local
export NDS_FLAKE_REPO_URL="git+ssh://git@github.com/you/your-leaf.git"
# export NDS_FLAKE_LOCAL_PATH="/mnt/usb/my-flake"   # when NDS_FLAKE_SOURCE=local
export NDS_FLAKE_INSTALL_PATH="/mnt/opt/your-leaf"
export NDS_FLAKE_HOST="my-server"       # nixosConfigurations name
export NDS_FLAKE_HOST_DIR="hosts/x86_64-linux"
export NDS_DISK_PREP="nds"              # nds | skip
export NDS_HARDWARE_CONFIG="copy"       # copy | skip

# =============================================================================
# DISK & ENCRYPTION
# =============================================================================

export NDS_DISK_TARGET="/dev/vda"
export NDS_ENCRYPTION="false"
export NDS_ENCRYPTION_KEY_LENGTH="64"
export NDS_ENCRYPTION_USE_PASSPHRASE="n"

# =============================================================================
# NETWORK — not used by installFlake (configure in your flake)
# =============================================================================

# export NDS_NETWORK_METHOD="dhcp"

# =============================================================================
# OPTIONAL
# =============================================================================

# export NDS_AUTO_CONFIRM="true"
# export DEBUG="1"
