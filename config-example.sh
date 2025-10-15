#!/usr/bin/env bash
# ==================================================================================================
# Digital Paradise Swarm - Bootstrap Configuration Example by CodeAnthem
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2024-10-15 | Modified: 2025-10-15
# Description:   Configuration template for DPS bootstrap script deployment
# Feature:       Environment variable configuration with examples and defaults
# ==================================================================================================
#
# Copy this file and modify the values for your environment
# Source this file before running the bootstrap script

# =============================================================================
# GLOBAL CONFIGURATION (OPTIONAL - HAS DEFAULTS)
# =============================================================================


# Network Defaults
export DPS_NETWORK_GATEWAY="192.168.0.1"
export DPS_NETWORK_MASK="255.255.255.0"
export DPS_NETWORK_DNS_PRIMARY="1.1.1.1"
export DPS_NETWORK_DNS_SECONDARY="1.0.0.1"

# System Defaults
export DPS_ADMIN_USER="admin"

# Disk Defaults
export DPS_DISK_TARGET="/dev/sda"
export DPS_DISK_ENCRYPTION_ENABLED="n"
export DPS_DISK_ENCRYPTION_KEY_LENGTH="32"
export DPS_DISK_ENCRYPTION_USE_PASSPHRASE="n"
export DPS_DISK_ENCRYPTION_PASSPHRASE_LENGTH="32"
export DPS_DISK_ENCRYPTION_GENERATE="urandom"

# =============================================================================
# REQUIRED HOST CONFIGURATION
# =============================================================================

# Required Configuration
export DPS_GIT_REPO="https://github.com/YOUR_USERNAME/YOUR_REPO.git"  # Git repository URL
export DPS_NETWORK_HOSTNAME="worker-01"                          # Hostname for this node
export DPS_NETWORK_ADDRESS="192.168.0.100"                      # Static IP address
export DPS_ROLE="worker"                                         # tooling, gateway, worker, gpu-worker

# =============================================================================
# USAGE EXAMPLES
# =============================================================================

# Example 1: Gateway Node
# export DPS_ROLE="gateway"
# export DPS_NETWORK_HOSTNAME="gateway-01"
# export DPS_NETWORK_ADDRESS="192.168.0.1"
# export DPS_DISK_ENCRYPTION_ENABLED="y"

# Example 2: GPU Worker Node
# export DPS_ROLE="gpu-worker"
# export DPS_NETWORK_HOSTNAME="gpu-worker-01"
# export DPS_NETWORK_ADDRESS="192.168.0.200"
# export DPS_DISK_TARGET="/dev/nvme0n1"

# Example 3: Tooling Node
# export DPS_ROLE="tooling"
# export DPS_NETWORK_HOSTNAME="tooling-01"
# export DPS_NETWORK_ADDRESS="192.168.0.10"
# export DPS_DISK_ENCRYPTION_ENABLED="y"
# export DPS_ADMIN_USER="tooling-admin"
