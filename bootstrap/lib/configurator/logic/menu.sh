#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-11-05
# Description:   Configurator v4.1 - Interactive Menu & Workflows
# Feature:       High-level user workflows and interactive configuration menu
# ==================================================================================================

# =============================================================================
# WORKFLOWS
# =============================================================================

nds_cfg_validate_all() {
    local presets=("$@")
    # If no presets specified, get all from registry (sorted by priority)
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_cfg_preset_getAllSorted)
    fi
    declare -p | grep presets
    nds_cfg_preset_validate_all
}

nds_cfg_prompt_errors() {
    local presets=("$@")
    # If no presets specified, get all from registry (sorted by priority)
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_cfg_preset_getAllSorted)
    fi
    section_header "Configuration Required"
    for preset in "${presets[@]}"; do
        nds_cfg_preset_prompt_errors "$preset"
    done
}

nds_cfg_menu() {
    local presets=("$@")
    local last_status=""
    
    # If no presets specified, get all from registry (sorted by priority)
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_cfg_preset_getAllSorted)
    fi
    
    while true; do
        section_header "Configuration Menu"
        [[ -n "$last_status" ]] && console "$last_status"
        
        local i=0
        for preset in "${presets[@]}"; do
            ((++i))
            nds_cfg_preset_display "$preset" "$i"
            console ""
        done

        # Auto-confirm if NDS_AUTO_CONFIRM is set to true
        if nds_autoSkip; then
            console "Auto-confirming configuration"
            return 0
        fi
        
        # Inner loop for re-prompting without redrawing menu
        while true; do
            read -sr -n 1 -p "Select preset (1-$i or X to proceed): " sel < /dev/tty
            echo
            
            # Handle empty input (just ENTER) - re-prompt
            if [[ -z "$sel" ]]; then
                continue
            fi
            
            if [[ "${sel,,}" == "x" ]]; then
                if ! nds_cfg_validate_all "${presets[@]}"; then
                    last_status=$(warn "Configuration has errors. Fix before proceeding.")
                    break  # Break to redraw menu with error
                fi
                success "Configuration confirmed"
                return 0
            elif [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 ]] && [[ "$sel" -le "$i" ]]; then
                local preset="${presets[$((sel-1))]}"
                
                while true; do
                    console ""
                    local display
                    display=$(nds_cfg_preset_get "$preset" "display")
                    # Only add Configuration suffix if display name doesn't already contain it
                    [[ "$display" != *"Configuration"* ]] && display="${display} Configuration"
                    section_header "$display"
                    console " Press ENTER to keep current value, or type new value"
                    console ""
                    
                    nds_cfg_preset_prompt_all "$preset"
                    
                    if nds_cfg_preset_validate "$preset" 2>/dev/null; then
                        last_status=$(success "$(nds_cfg_preset_get "$preset" "display") updated")
                        break
                    fi
                done
                break  # Break to redraw menu with success status
            else
                warn "Invalid selection"
                # Continue inner loop to re-prompt
            fi
        done
    done
}

nds_cfg_run() {
    local presets=("$@")
    
    if ! nds_cfg_validate_all "${presets[@]}"; then
        nds_cfg_prompt_errors "${presets[@]}"
        
        if ! nds_cfg_validate_all "${presets[@]}"; then
            error "Configuration validation failed"
            return 1
        fi
    fi
    
    nds_cfg_menu "${presets[@]}"
}
