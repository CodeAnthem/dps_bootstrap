#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Deploy VM Configuration Example
# ==================================================================================================

# Deploy VM Configuration
export DPS_HOSTNAME="deploy-01"
export DPS_NETWORK_METHOD="dhcp"  # or "static"
export DPS_IP_ADDRESS=""          # Only needed if using static networking
export DPS_NETWORK_GATEWAY="192.168.1.1"
export DPS_ENCRYPTION="y"         # Deploy VM should be encrypted
export DPS_DISK_TARGET="/dev/sda" # Adjust for your system
export DPS_ADMIN_USER="admin"

# Optional encryption settings
export DPS_DISK_ENCRYPTION_KEY_LENGTH="32"
export DPS_DISK_ENCRYPTION_USE_PASSPHRASE="n"
export DPS_DISK_ENCRYPTION_GENERATE="urandom"

# Debug mode (optional)
export DPS_DEBUG="0"

# Usage:
# 1. Copy this file and customize values
# 2. Source the file: source my-deploy-config.sh
# 3. Run bootstrap: curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/bootstrap.sh | bash
