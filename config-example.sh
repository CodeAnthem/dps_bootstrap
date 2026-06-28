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

# =============================================================================
# DISK & ENCRYPTION
# =============================================================================

export NDS_DISK_TARGET="/dev/vda"
export NDS_ENCRYPTION="false"
export NDS_ENCRYPTION_KEY_LENGTH="64"
export NDS_ENCRYPTION_USE_PASSPHRASE="n"

# =============================================================================
# NETWORK
# =============================================================================

export NDS_HOSTNAME="my-server"         # must match FLAKE_HOST unless you set both explicitly
export NDS_NETWORK_METHOD="dhcp"
# export NDS_NETWORK_IP="192.168.1.100"
# export NDS_NETWORK_MASK="255.255.255.0"
# export NDS_NETWORK_GATEWAY="192.168.1.1"
export NDS_NETWORK_DNS_PRIMARY="1.1.1.1"
export NDS_NETWORK_DNS_SECONDARY="1.0.0.1"

# =============================================================================
# OPTIONAL
# =============================================================================

# export NDS_AUTO_CONFIRM="true"
# export DEBUG="1"
