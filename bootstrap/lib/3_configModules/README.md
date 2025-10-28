# Modules Directory

This directory contains unified configuration and NixOS generation modules.

## Architecture

Each module file contains both:
1. **Configuration** - Field declarations, validation, and conditional logic
2. **NixOS Generation** - Functions to generate NixOS configuration blocks

## Module Structure

```bash
#!/usr/bin/env bash
# Module Header with description

# =============================================================================
# CONFIGURATION - Field Declarations
# =============================================================================
module_init_callback() {
    # Declare configuration fields
    nds_field_declare FIELD_NAME \
        display="Field Display Name" \
        input=type \
        default="value" \
        required=true
}

# =============================================================================
# CONFIGURATION - Active Fields Logic (OPTIONAL)
# =============================================================================
module_get_active_fields() {
    # Return list of active fields (for conditional field visibility)
    # If not implemented, all declared fields are active
    echo "FIELD_NAME"
}

# =============================================================================
# CONFIGURATION - Cross-Field Validation (OPTIONAL)
# =============================================================================
module_validate_extra() {
    # Validate relationships between multiple fields
    # Return 0 for success, 1 for failure
    return 0
}

# =============================================================================
# NIXOS CONFIG GENERATION - Public API (OPTIONAL)
# =============================================================================
nds_nixcfg_module_auto() {
    # Auto-mode: reads from configuration modules
    local field_value
    field_value=$(nds_config_get "module" "FIELD_NAME")
    
    local block
    block=$(_nixcfg_module_generate "$field_value")
    nds_nixcfg_register "module" "$block" 10
}

# =============================================================================
# NIXOS CONFIG GENERATION - Implementation
# =============================================================================
_nixcfg_module_generate() {
    # Generate NixOS configuration from parameters
    cat <<EOF
# NixOS configuration block
setting = "$1";
EOF
}
```

## Available Modules

### Core Installation
- **access.sh** - Admin user, sudo, SSH server and key configuration
- **network.sh** - Hostname, network method (DHCP/static), IP configuration
- **disk.sh** - Disk partitioning and encryption
- **boot.sh** - Bootloader and UEFI configuration

### Security
- **security.sh** - Secure boot, firewall, hardening, fail2ban

### Regional Settings
- **region.sh** - Country auto-defaults, timezone, locale, keyboard

### Optional
- **packages.sh** - System packages, Nix flakes (not used in bootstrap)

## Module Loading

Modules are auto-initialized by the workflow:

```bash
# In action setup.sh
setup() {
    # Modules auto-initialize - just define workflow order
    nds_config_workflow "access" "network" "disk" "boot" "security" "region" "deploy"
}
```

## Benefits of Unified Modules

1. **Single Source of Truth** - All module logic in one file
2. **Easier Maintenance** - Add field → add generation in same file
3. **Better Cohesion** - Config input and output together
4. **Clearer Intent** - Obvious how fields map to NixOS config
5. **Simpler Architecture** - One directory vs two separate ones

## Migration from Old Structure

**Before:**
```
bootstrap/lib/
├── 2_configuration/modules/      # Config fields
└── nixosConfigBuilder/builderModules/  # NixOS generation
```

**After:**
```
bootstrap/lib/modules/  # Both config + generation
```

All module loading automatically uses the new unified location.
