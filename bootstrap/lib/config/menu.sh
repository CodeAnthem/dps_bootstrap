#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Configurator - Workflows
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-24 | Modified: 2025-10-30
# Description:   High-level user workflows and interactive menu
# Dependencies:  storage.sh, var.sh, preset.sh
# ==================================================================================================

# =============================================================================
# WORKFLOWS
# =============================================================================

nds_configurator_validate_all() {
    local presets=("$@")
    # If no presets specified, get all enabled from registry
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_configurator_preset_get_all_enabled)
    fi
    nds_configurator_preset_validate_all "${presets[@]}"
}

nds_configurator_prompt_errors() {
    local presets=("$@")
    # If no presets specified, get all enabled from registry
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_configurator_preset_get_all_enabled)
    fi
    section_header "Configuration Required"
    for preset in "${presets[@]}"; do
        nds_configurator_preset_prompt_errors "$preset"
    done
}

nds_configurator_menu() {
    local presets=("$@")
    local last_status=""
    
    # If no presets specified, get all enabled from registry
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_configurator_preset_get_all_enabled)
    fi
    
    while true; do
        section_header "Configuration Menu"
        [[ -n "$last_status" ]] && console "$last_status"
        
        local i=0
        for preset in "${presets[@]}"; do
            ((++i))
            nds_configurator_preset_display "$preset" "$i"
            console ""
        done
        
        read -sr -n 1 -p "Select preset (1-$i or X to proceed): " sel < /dev/tty
        echo
        
        if [[ "${sel,,}" == "x" ]]; then
            if ! nds_configurator_validate_all "${presets[@]}"; then
                warn "Configuration has errors. Fix before proceeding."
                read -p "Press ENTER..." -r
                continue
            fi
            success "Configuration confirmed"
            return 0
        elif [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 ]] && [[ "$sel" -le "$i" ]]; then
            local preset="${presets[$((sel-1))]}"
            
            while true; do
                console ""
                local display
                display=$(nds_configurator_preset_get_display "$preset")
                # Only add Configuration suffix if display name doesn't already contain it
                [[ "$display" != *"Configuration"* ]] && display="${display} Configuration"
                section_header "$display"
                console " Press ENTER to keep current value, or type new value"
                console ""
                
                nds_configurator_preset_prompt_all "$preset"
                
                if nds_configurator_preset_validate "$preset" 2>/dev/null; then
                    last_status=$(success "$(nds_configurator_preset_get_display "$preset") updated")
                    break
                fi
            done
        else
            last_status=""
            warn "Invalid selection"
            read -p "Press ENTER..." -r
        fi
    done
}

nds_configurator_run() {
    local presets=("$@")
    
    if ! nds_configurator_validate_all "${presets[@]}"; then
        nds_configurator_prompt_errors "${presets[@]}"
        
        if ! nds_configurator_validate_all "${presets[@]}"; then
            error "Configuration validation failed"
            return 1
        fi
    fi
    
    nds_configurator_menu "${presets[@]}"
}
