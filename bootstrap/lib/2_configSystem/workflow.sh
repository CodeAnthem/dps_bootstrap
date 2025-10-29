#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System - Workflows
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-27
# Description:   High-level user workflows
# Dependencies:  3_module.sh
# ==================================================================================================

# =============================================================================
# MODULE INITIALIZATION (Called by main.sh)
# =============================================================================

# Initialize modules - called by main.sh BEFORE sourcing setup.sh
# Usage: nds_config_init_modules "module1" "module2" ...
nds_config_init_modules() {
    local modules=("$@")
    
    for module in "${modules[@]}"; do
        # Check if module has fields declared already
        local has_fields=false
        for key in "${!FIELD_REGISTRY[@]}"; do
            if [[ "$key" =~ ^${module}__.*__display$ ]]; then
                has_fields=true
                break
            fi
        done
        
        # Initialize if no fields found
        if [[ "$has_fields" == "false" ]]; then
            debug "Initializing module: $module"
            nds_config_init_module "$module" || {
                error "Failed to initialize module: $module"
                return 1
            }
        fi
    done
}

# =============================================================================
# PUBLIC API FOR SETUP.SH
# =============================================================================

# Validate all modules - returns 0 if valid, 1 if errors
# Usage: nds_config_validate "module1" "module2" ...
nds_config_validate() {
    local modules=("$@")
    local has_errors=false
    
    for module in "${modules[@]}"; do
        if ! nds_module_validate "$module" 2>/dev/null; then
            has_errors=true
        fi
    done
    
    if $has_errors; then
        return 1
    fi
    return 0
}

# Prompt for missing/invalid fields only
# Usage: nds_config_prompt_missing "module1" "module2" ...
nds_config_prompt_missing() {
    local modules=("$@")
    section_header "Configuration Required"
    
    for module in "${modules[@]}"; do
        nds_module_prompt_errors "$module"
    done
}

# =============================================================================
# HIGH-LEVEL WORKFLOWS
# =============================================================================

# Fix validation errors only (minimal prompting)
# Usage: nds_config_fix_errors "module1" "module2" ...
nds_config_fix_errors() {
    local modules=("$@")
    section_header "Configuration Required"

    # Prompt for missing/invalid fields in each module
    for module in "${modules[@]}"; do
        nds_module_prompt_errors "$module"
    done
}

# Interactive category selection menu
# Usage: nds_config_menu "module1" "module2" ...
nds_config_menu() {
    local modules=("$@")

    while true; do
        section_header "Configuration Menu"

        # Show current configuration with numbers
        local i=0
        for module in "${modules[@]}"; do
            ((++i))
            nds_module_display "$module" "$i"
            console ""
        done

        # Build menu
        read -sr -n 1 -p "Select category (1-$i or X to proceed):" selection < /dev/tty
        echo  # Newline after single-char input

        if [[ "${selection,,}" == "x" ]]; then
            # Validate before confirming
            local validation_errors=0
            for module in "${modules[@]}"; do
                if ! nds_module_validate "$module"; then
                    ((validation_errors++))
                fi
            done

            if [[ "$validation_errors" -gt 0 ]]; then
                warn "Configuration still has $validation_errors error(s)."
                warn "Please fix all errors before proceeding."
                read -p "Press ENTER to continue..." -r
                console ""
                continue
            fi

            success "Configuration confirmed"
            return 0
        elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "$i" ]]; then
            # Valid selection - edit that module
            local selected_module="${modules[$((selection-1))]}"
            local validation_output=""
            
            # Loop until module validates
            while true; do
                console ""
                section_header "$(echo "${selected_module^}" | tr '_' ' ') Configuration"
                
                # Show validation errors from previous iteration (if any)
                if [[ -n "$validation_output" ]]; then
                    echo "$validation_output" >&2
                    console ""
                fi
                
                console " Press ENTER to keep current value, or type new value"
                console ""
                nds_module_prompt_all "$selected_module"
                
                # Validate and capture output
                validation_output=$(nds_module_validate "$selected_module" 2>&1)
                local validation_result=$?
                
                if [[ "$validation_result" -eq 0 ]]; then
                    # Valid - exit loop
                    success "$(echo "${selected_module^}" | tr '_' ' ') configuration updated"
                    break
                fi
                # Invalid - loop again with captured errors
            done
        else
            warn "Invalid selection. Please enter 1-$i or X to proceed."
            read -p "Press ENTER to continue..." -r
            console ""
        fi
    done
}

# Complete configuration workflow (convenience function)
# Usage: nds_config_workflow "module1" "module2" ...
nds_config_workflow() {
    local modules=("$@")

    # Validate
    if ! nds_config_validate "${modules[@]}"; then
        # Prompt for missing/invalid
        nds_config_prompt_missing "${modules[@]}"
        
        # Re-validate
        if ! nds_config_validate "${modules[@]}"; then
            error "Configuration validation failed"
            return 1
        fi
    fi

    # Show interactive menu
    nds_config_menu "${modules[@]}"
    return $?
}
