#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-07-04
# Description:   NixOS Config Generation - Boot Module
# Feature:       Bootloader configuration (systemd-boot, GRUB, rEFInd)
# ==================================================================================================

# =============================================================================
# NIXOS CONFIG GENERATION - Public API
# =============================================================================

# Auto-mode: reads from configuration modules
nds_nixcfg_boot_auto() {
    local bootloader uefi
    bootloader=$(nds_config_get "boot" "BOOT_LOADER")
    uefi=$(nds_config_get "boot" "BOOT_UEFI_MODE")

    _nixcfg_boot_generate "$bootloader" "$uefi"
}

# Flake install: same boot preset as classicInstall, wrapped in lib.mkForce so the
# generated nds-boot.nix module overrides eval stubs in the flake.
nds_nixcfg_boot_auto_flake() {
    local bootloader uefi
    bootloader=$(nds_config_get "boot" "BOOT_LOADER")
    uefi=$(nds_config_get "boot" "BOOT_UEFI_MODE")

    _nixcfg_boot_generate_flake "$bootloader" "$uefi"
}

# Manual mode: explicit parameters
nds_nixcfg_boot() {
    local bootloader="$1"
    local uefi="${2:-true}"

    _nixcfg_boot_generate "$bootloader" "$uefi"
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================

_nixcfg_boot_generate() {
    local bootloader="$1"
    local uefi="$2"

    if [[ "$uefi" != "true" && "$bootloader" == "systemd-boot" ]]; then
        warn "systemd-boot requires UEFI — generating GRUB for BIOS boot"
        bootloader=grub
    elif [[ "$uefi" != "true" && "$bootloader" == "refind" ]]; then
        warn "rEFInd requires UEFI — generating GRUB for BIOS boot"
        bootloader=grub
    fi

    case "$bootloader" in
        systemd-boot)
            _nixcfg_boot_systemd "$uefi"
            ;;
        grub)
            _nixcfg_boot_grub "$uefi" false
            ;;
        refind)
            _nixcfg_boot_refind "$uefi"
            ;;
        *)
            error "Unknown bootloader: $bootloader"
            return 1
            ;;
    esac
}

_nixcfg_boot_generate_flake() {
    local bootloader="$1"
    local uefi="$2"

    if [[ "$uefi" != "true" && "$bootloader" == "systemd-boot" ]]; then
        warn "systemd-boot requires UEFI — generating GRUB for BIOS boot"
        bootloader=grub
    elif [[ "$uefi" != "true" && "$bootloader" == "refind" ]]; then
        warn "rEFInd requires UEFI — generating GRUB for BIOS boot"
        bootloader=grub
    fi

    case "$bootloader" in
        systemd-boot)
            _nixcfg_boot_systemd_flake "$uefi"
            ;;
        grub)
            _nixcfg_boot_grub "$uefi" true
            ;;
        refind)
            _nixcfg_boot_refind_flake "$uefi"
            ;;
        *)
            error "Unknown bootloader: $bootloader"
            return 1
            ;;
    esac
}

_nixcfg_boot_systemd() {
    local uefi="$1"

    if [[ "$uefi" != "true" ]]; then
        error "systemd-boot cannot be used without UEFI"
        return 1
    fi

    local block
    block=$(cat <<'EOF'
boot.loader = {
  systemd-boot.enable = true;
  efi.canTouchEfiVariables = true;
};
EOF
)

    nds_nixcfg_register "boot" "$block" 10
}

_nixcfg_boot_grub() {
    local uefi="$1"
    local use_force="${2:-false}"
    local disk

    disk=$(nds_config_get "disk" "DISK_TARGET")

    local block
    if [[ "$uefi" == "true" ]]; then
        if [[ "$use_force" == "true" ]]; then
            block=$(cat <<'EOF'
boot.loader = lib.mkForce {
  grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = false;
  };
  efi.canTouchEfiVariables = true;
};
EOF
)
        else
            block=$(cat <<'EOF'
boot.loader = {
  grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = false;
  };
  efi.canTouchEfiVariables = true;
};
EOF
)
        fi
    else
        if [[ "$use_force" == "true" ]]; then
            block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.loader.grub = lib.mkForce {
  enable = true;
  device = "@@DISK@@";
};
EOF
)" @@DISK@@ "$disk")
        else
            block=$(nds_nixcfg_subst "$(cat <<'EOF'
boot.loader.grub = {
  enable = true;
  device = "@@DISK@@";
};
EOF
)" @@DISK@@ "$disk")
        fi
    fi

    nds_nixcfg_register "boot" "$block" 10
}

_nixcfg_boot_systemd_flake() {
    local uefi="$1"

    if [[ "$uefi" != "true" ]]; then
        error "systemd-boot cannot be used without UEFI"
        return 1
    fi

    local block
    block=$(cat <<'EOF'
boot.loader = lib.mkForce {
  systemd-boot.enable = true;
  efi.canTouchEfiVariables = true;
};
EOF
)

    nds_nixcfg_register "boot" "$block" 10
}

_nixcfg_boot_refind_flake() {
    local uefi="$1"

    if [[ "$uefi" != "true" ]]; then
        error "rEFInd cannot be used without UEFI"
        return 1
    fi

    local block
    block=$(cat <<'EOF'
boot.loader = lib.mkForce {
  refind.enable = true;
  efi.canTouchEfiVariables = true;
};
EOF
)

    nds_nixcfg_register "boot" "$block" 10
}

_nixcfg_boot_refind() {
    local uefi="$1"

    if [[ "$uefi" != "true" ]]; then
        error "rEFInd cannot be used without UEFI"
        return 1
    fi

    local block
    block=$(cat <<'EOF'
boot.loader = {
  refind.enable = true;
  efi.canTouchEfiVariables = true;
};
EOF
)

    nds_nixcfg_register "boot" "$block" 10
}
