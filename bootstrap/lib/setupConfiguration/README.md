# Configuration System v2.0

Generic field-based configuration with declarative metadata.

---

## Code Reduction

- **network.sh**: 416 lines → 110 lines (73% reduction)
- **disk.sh**: 506 lines → 87 lines (83% reduction)
- **custom.sh**: 210 lines → 60 lines (71% reduction)
- **Total**: ~1132 lines → ~257 lines (77% reduction)

---

## Usage

### Declare Fields

```bash
network_init_callback() {
    # MODULE_CONTEXT is set automatically
    
    field_declare HOSTNAME \
        display="Hostname" \
        required=true \
        validator=validate_hostname \
        error="Invalid hostname"
    
    field_declare NETWORK_METHOD \
        display="Network Method" \
        type=choice \
        options="dhcp|static" \
        default=dhcp
}
```

### Active Fields Logic

```bash
network_get_active_fields() {
    local method=$(config_get "NETWORK_METHOD")
    
    echo "HOSTNAME NETWORK_METHOD"
    [[ "$method" == "static" ]] && echo "IP_ADDRESS NETWORK_MASK"
}
```

### Cross-Field Validation

```bash
network_validate_extra() {
    # Optional: validate relationships between fields
    return 0
}
```

### Register Module

```bash
config_register_module "network" \
    "network_init_callback" \
    "network_get_active_fields"
```

---

## Field Attributes

| Attribute | Required | Description |
|-----------|----------|-------------|
| `display` | Yes | Label shown to user |
| `required` | No | true/false (default: false) |
| `default` | No | Default value |
| `validator` | No | Function name from inputValidation/ |
| `error` | No | Error message |
| `type` | No | choice, bool, number, or text (default) |
| `options` | No | For choice type: "opt1\|opt2\|opt3" |
| `min`/`max` | No | For number type |

---

## Workflow

1. Action calls `config_init_module("module")`
2. Module's init callback declares fields
3. DPS_* env vars applied automatically
4. `config_workflow("module1", "module2")` orchestrates:
   - Validate all fields
   - Fix only broken fields
   - Show summary
   - Category menu if user wants changes

---

## API

```bash
# Initialize
config_init_module "network"

# Workflow
config_workflow "network" "disk" "custom"

# Get/Set values
config_get "network" "HOSTNAME"
config_set "network" "HOSTNAME" "myserver"

# Or use MODULE_CONTEXT
MODULE_CONTEXT="network"
config_get "HOSTNAME"
```

---

## Generic Operations

All these work automatically via field metadata:

- **Validation**: `module_validate "network"` - iterates active fields
- **Prompting**: `module_prompt_errors "network"` - only failed fields
- **Display**: `module_display "network"` - shows active fields

---

## Environment Variables

Any field can be overridden:

```bash
export DPS_HOSTNAME=myserver
export DPS_ADMIN_USER=admin
# Applied automatically during config_init_module
```

---

**No more 200-line interactive callbacks!**
