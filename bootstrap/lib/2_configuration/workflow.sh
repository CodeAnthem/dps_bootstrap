#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configuration System - Workflows
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-24
# Description:   High-level user workflows
# Dependencies:  3_module.sh
# ==================================================================================================

# =============================================================================
# HIGH-LEVEL WORKFLOWS
# =============================================================================

# Fix validation errors only (minimal prompting)
# Usage: config_fix_errors "module1" "module2" ...
config_fix_errors() {
    local modules=("$@")
    section_header "Configuration Required"

    # Prompt for missing/invalid fields in each module
    for module in "${modules[@]}"; do
        module_prompt_errors "$module"
    done
}

# Interactive category selection menu
# Usage: config_menu "module1" "module2" ...
config_menu() {
    local modules=("$@")

    while true; do
        section_header "Configuration Menu"

        # Show current configuration with numbers
        local i=0
        for module in "${modules[@]}"; do
            ((++i))
            module_display "$module" "$i"
            console ""
        done

        # Build menu
        read -sr -n 1 -p "Select category (1-$i or X to proceed):" selection < /dev/tty
        echo  # Newline after single-char input

        if [[ "${selection,,}" == "x" ]]; then
            # Validate before confirming
            local validation_errors=0
            for module in "${modules[@]}"; do
                if ! module_validate "$module"; then
                    ((validation_errors++))
                fi
            done

            if [[ "$validation_errors" -gt 0 ]]; then
                warn "Configuration still has $validation_errors error(s)."
                warn "Please fix all errors before proceeding."
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
                    console ""
                    warn "Previous validation errors - please fix:"
                    echo "$validation_output" >&2
                    console ""
                fi
                
                console "Press ENTER to keep current value, or type new value"
                console ""
                module_prompt_all "$selected_module"
                
                # Validate and capture output
                validation_output=$(module_validate "$selected_module" 2>&1)
                local validation_result=$?
                
                if [[ $validation_result -eq 0 ]]; then
                    # Valid - exit loop
                    success "$(echo "${selected_module^}" | tr '_' ' ') configuration updated"
                    break
                fi
                # Invalid - loop again with captured errors
            done
        else
            warn "Invalid selection. Please enter 1-$i or X to proceed."
        fi
    done
}

# Complete configuration workflow
# Usage: config_workflow "module1" "module2" ...
config_workflow() {
    local modules=("$@")

    # Check if any fields are missing (silent check)
    local needs_input=false
    for module in "${modules[@]}"; do
        if ! module_validate "$module" 2>/dev/null; then
            needs_input=true
            break
        fi
    done

    # If validation fails, prompt for required fields
    if [[ "$needs_input" == "true" ]]; then
        config_fix_errors "${modules[@]}"

        # Re-validate after input
        local validation_errors=0
        for module in "${modules[@]}"; do
            if ! module_validate "$module"; then
                ((validation_errors++))
            fi
        done

        if [[ "$validation_errors" -gt 0 ]]; then
            error "Configuration validation still has $validation_errors error(s)"
            return 1
        fi

        success "Configuration completed"
    fi

    # Display all configurations
    section_header "Configuration Summary"
    for module in "${modules[@]}"; do
        module_display "$module"
        console ""
    done

    # Ask if user wants to modify anything
    while true; do
        read -rsn 1 -p "-> Do you want to modify any settings? [y/n]: " response < /dev/tty

        case "${response,,}" in
            y|yes)
                # Show interactive menu
                console "Yes"
                if config_menu "${modules[@]}"; then
                    # User pressed X in menu to proceed - confirmed
                    return 0
                fi

                # User exited menu without X, show updated config and ask again
                console ""
                section_header "Configuration Summary"
                for module in "${modules[@]}"; do
                    module_display "$module"
                    console ""
                done
                ;;
            n|no)
                console "No"
                success "Configuration confirmed"
                return 0
                ;;
            "") ;;
            *)
                console "Invalid input - Please enter 'y' or 'n'"
                ;;
        esac
    done
}
