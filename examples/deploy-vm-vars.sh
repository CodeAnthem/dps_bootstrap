#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Deploy VM Configuration Example
# ==================================================================================================

# Deploy VM Configuration
export NDS_HOSTNAME="deploy-01"
export NDS_NETWORK_METHOD="dhcp"  # or "static"
export NDS_IP_ADDRESS=""          # Only needed if using static networking
export NDS_NETWORK_GATEWAY="192.168.1.1"
export NDS_ENCRYPTION="y"         # Deploy VM should be encrypted
export NDS_DISK_TARGET="/dev/sda" # Adjust for your system
export NDS_ADMIN_USER="admin"

# Optional encryption settings
export NDS_DISK_ENCRYPTION_KEY_LENGTH="32"
export NDS_DISK_ENCRYPTION_USE_PASSPHRASE="n"
export NDS_DISK_ENCRYPTION_GENERATE="urandom"

# Debug mode (optional)
export NDS_DEBUG="0"

# Usage:
# 1. Copy this file and customize values
# 2. Source the file: source my-deploy-config.sh
# 3. Run bootstrap: curl -sSL https://raw.githubusercontent.com/codeAnthem/NDS_bootstrap/main/bootstrap.sh | bash
