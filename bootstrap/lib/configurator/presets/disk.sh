#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Disk Preset
# Feature:       Disk partitioning, encryption, swap configuration
# ==================================================================================================

# Create preset
nds_cfg_preset_create "disk" \
    --display "Disk" \
    --priority 20

# Auto-detect first disk if not provided
first_disk=$(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort | head -n1)

# Base settings (always visible)
nds_cfg_setting_create DISK_TARGET \
    --type disktype \
    --display "Target Disk" \
    --default "$first_disk"

nds_cfg_setting_create ENCRYPTION \
    --type toggle \
    --display "Enable Encryption" \
    --default "true"

nds_cfg_setting_create PARTITION_STRATEGY \
    --type choice \
    --display "Partition Strategy" \
    --default "fast" \
    --options "fast|disko"

nds_cfg_setting_create AUTO_APPROVE_DISK_PURGE \
    --type toggle \
    --display "Auto-approve Disk Purge" \
    --default "false"

# Disko user file (visible if strategy is disko or if custom file path provided)
nds_cfg_setting_create DISKO_USER_FILE \
    --type path \
    --display "Disko File (override)" \
    --default ""

# Filesystem settings (hidden if custom disko file provided)
nds_cfg_setting_create FS_TYPE \
    --type choice \
    --display "Filesystem Type" \
    --default "btrfs" \
    --options "btrfs|ext4"

nds_cfg_setting_create SWAP_SIZE_MIB \
    --type int \
    --display "Swap Size (MiB)" \
    --default "0" \
    --min 0

nds_cfg_setting_create SEPARATE_HOME \
    --type toggle \
    --display "Separate /home" \
    --default "false"

nds_cfg_setting_create HOME_SIZE \
    --type string \
    --display "/home Size (if separate)" \
    --default "20G" \
    --visible_all "SEPARATE_HOME==true"

# Encryption settings (visible only if encryption enabled)
nds_cfg_setting_create ENCRYPTION_KEY_METHOD \
    --type choice \
    --display "Encryption Key Method" \
    --default "urandom" \
    --options "urandom|openssl|manual" \
    --visible_all "ENCRYPTION==true"

nds_cfg_setting_create ENCRYPTION_KEY_LENGTH \
    --type int \
    --display "Encryption Key Length" \
    --default "64" \
    --min 32 \
    --max 512 \
    --visible_all "ENCRYPTION==true"

nds_cfg_setting_create ENCRYPTION_USE_PASSPHRASE \
    --type toggle \
    --display "Use Passphrase" \
    --default "false" \
    --visible_all "ENCRYPTION==true"

nds_cfg_setting_create ENCRYPTION_UNLOCK_MODE \
    --type choice \
    --display "Encryption Unlock Mode" \
    --default "manual" \
    --options "manual|dropbear|tpm|keyfile" \
    --visible_all "ENCRYPTION==true"

# Passphrase settings (visible only if encryption and passphrase enabled)
nds_cfg_setting_create ENCRYPTION_PASSPHRASE_METHOD \
    --type choice \
    --display "Passphrase Generation Method" \
    --default "urandom" \
    --options "urandom|openssl|manual" \
    --visible_all "ENCRYPTION==true ENCRYPTION_USE_PASSPHRASE==true"

nds_cfg_setting_create ENCRYPTION_PASSPHRASE_LENGTH \
    --type int \
    --display "Passphrase Length" \
    --default "32" \
    --min 16 \
    --max 512 \
    --visible_all "ENCRYPTION==true ENCRYPTION_USE_PASSPHRASE==true"

