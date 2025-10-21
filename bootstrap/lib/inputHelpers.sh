#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-21 | Modified: 2025-10-21
# Description:   Script Library File
# Feature:       Reusable input validation and prompt helpers
# ==================================================================================================

# =============================================================================
# REUSABLE INPUT VALIDATION HELPERS
# =============================================================================

# Prompt for input with validation
# Usage: prompt_validated "label" "current_value" "validation_function" ["required"|"optional"] ["error_message"]
prompt_validated() {
    local label="$1"
    local current_value="$2"
    local validation_func="$3"
    local required="${4:-optional}"
    local error_msg="${5:-Invalid input}"
    
    while true; do
        printf "  %-20s [%s]: " "$label" "$current_value" >&2
        read -r new_value < /dev/tty
        
        # Empty input handling
        if [[ -z "$new_value" ]]; then
            if [[ -n "$current_value" ]]; then
                # Keep current value
                echo "$current_value"
                return 0
            elif [[ "$required" == "optional" ]]; then
                # Optional field, accept empty
                echo ""
                return 0
            else
                # Required field, empty not allowed
                console "    Error: $label is required"
                continue
            fi
        fi
        
        # Validate new input
        if $validation_func "$new_value"; then
            echo "$new_value"
            return 0
        else
            console "    Error: $error_msg"
            continue
        fi
    done
}

# Prompt for boolean choice (Y/N)
# Usage: prompt_bool "label" "current_value" ["default_on_empty"]
prompt_bool() {
    local label="$1"
    local current_value="$2"
    local default="${3:-}"
    
    while true; do
        printf "  %-20s [%s] (y/n): " "$label" "$current_value" >&2
        read -r new_value < /dev/tty
        
        # Empty input
        if [[ -z "$new_value" ]]; then
            if [[ -n "$current_value" ]]; then
                echo "$current_value"
                return 0
            elif [[ -n "$default" ]]; then
                echo "$default"
                return 0
            else
                console "    Error: Please enter 'y' or 'n'"
                continue
            fi
        fi
        
        # Validate yes/no
        if validate_yes_no "$new_value"; then
            local normalized="${new_value,,}"
            [[ "$normalized" == "yes" ]] && normalized="y"
            [[ "$normalized" == "no" ]] && normalized="n"
            echo "$normalized"
            return 0
        else
            console "    Error: Please enter 'y' or 'n'"
            continue
        fi
    done
}

# Prompt for choice from options
# Usage: prompt_choice "label" "current_value" "option1|option2|option3"
prompt_choice() {
    local label="$1"
    local current_value="$2"
    local options="$3"
    
    while true; do
        printf "  %-20s [%s] (%s): " "$label" "$current_value" "$options" >&2
        read -r new_value < /dev/tty
        
        # Empty input - keep current
        if [[ -z "$new_value" ]]; then
            if [[ -n "$current_value" ]]; then
                echo "$current_value"
                return 0
            else
                console "    Error: $label is required"
                continue
            fi
        fi
        
        # Validate choice
        if validate_choice "$new_value" "$options"; then
            echo "$new_value"
            return 0
        else
            console "    Error: Invalid choice. Options: $options"
            continue
        fi
    done
}

# Prompt for disk selection
# Usage: prompt_disk "label" "current_value"
prompt_disk() {
    local label="$1"
    local current_value="$2"
    
    # Show available disks
    local available_disks
    mapfile -t available_disks < <(list_available_disks)
    
    while true; do
        printf "  %-20s [%s]: " "$label" "$current_value" >&2
        read -r new_value < /dev/tty
        
        # Empty input - keep current
        if [[ -z "$new_value" ]]; then
            if [[ -n "$current_value" ]]; then
                echo "$current_value"
                return 0
            else
                console "    Error: $label is required" >&2
                continue
            fi
        fi
        
        # Check if it's a number (selection from list)
        if [[ "$new_value" =~ ^[0-9]+$ ]] && ((new_value >= 1 && new_value <= ${#available_disks[@]})); then
            local selected_disk="${available_disks[$((new_value-1))]}"
            new_value="${selected_disk%% *}"
        fi
        
        # Validate disk path
        if [[ -b "$new_value" ]]; then
            echo "$new_value"
            return 0
        else
            console "    Error: Disk '$new_value' does not exist or is not a block device" >&2
            continue
        fi
    done
}

# Prompt for numeric input
# Usage: prompt_number "label" "current_value" "min" "max" ["required"|"optional"]
prompt_number() {
    local label="$1"
    local current_value="$2"
    local min="${3:-}"
    local max="${4:-}"
    local required="${5:-optional}"
    
    while true; do
        local range_hint=""
        [[ -n "$min" && -n "$max" ]] && range_hint=" ($min-$max)"
        [[ -n "$min" && -z "$max" ]] && range_hint=" (min: $min)"
        [[ -z "$min" && -n "$max" ]] && range_hint=" (max: $max)"
        
        printf "  %-20s [%s]%s: " "$label" "$current_value" "$range_hint" >&2
        read -r new_value < /dev/tty
        
        # Empty input
        if [[ -z "$new_value" ]]; then
            if [[ -n "$current_value" ]]; then
                echo "$current_value"
                return 0
            elif [[ "$required" == "optional" ]]; then
                echo ""
                return 0
            else
                console "    Error: $label is required"
                continue
            fi
        fi
        
        # Validate numeric
        if [[ ! "$new_value" =~ ^[0-9]+$ ]]; then
            console "    Error: Must be a number"
            continue
        fi
        
        # Validate range
        if [[ -n "$min" && "$new_value" -lt "$min" ]]; then
            console "    Error: Must be at least $min"
            continue
        fi
        
        if [[ -n "$max" && "$new_value" -gt "$max" ]]; then
            console "    Error: Must be at most $max"
            continue
        fi
        
        echo "$new_value"
        return 0
    done
}

# =============================================================================
# CONFIGURATION UPDATE HELPERS
# =============================================================================

# Update config value if changed
# Usage: update_if_changed "module" "key" "old_value" "new_value"
update_if_changed() {
    local module="$1"
    local key="$2"
    local old_value="$3"
    local new_value="$4"
    
    if [[ "$new_value" != "$old_value" ]]; then
        config_set "$module" "$key" "$new_value"
        console "    -> Updated: $key = $new_value"
        return 0
    else
        console "    -> Unchanged"
        return 1
    fi
}
