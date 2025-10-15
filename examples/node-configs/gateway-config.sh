#!/usr/bin/env bash
# ==================================================================================================
# DPS Bootstrap - Gateway Node Configuration Example
# ==================================================================================================

# Managed Node Configuration
export DPS_ROLE="gateway"
export DPS_HOSTNAME="gateway-01"
export DPS_IP_ADDRESS="192.168.1.10"   # Gateway typically has lower IP
export DPS_NETWORK_GATEWAY="192.168.1.1"
export DPS_NETWORK_DNS_PRIMARY="1.1.1.1"
export DPS_NETWORK_DNS_SECONDARY="1.0.0.1"
export DPS_ENCRYPTION="y"         # Gateway should be encrypted
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
# 2. Source the file: source my-gateway-config.sh
# 3. Run bootstrap: curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/bootstrap.sh | bash
