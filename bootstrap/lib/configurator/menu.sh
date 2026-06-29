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

nds_configurator_wizard_intro() {
    section_header "Configuration wizard"
    nds_ui_b "NDS will ask only for missing required fields."
    nds_ui_b "Everything else keeps sensible defaults for now."
    nds_ui_b "You can fine-tune all options in the full menu afterward."
    nds_ui_b ""
}

nds_configurator_prompt_errors() {
    local presets=("$@")
    local prompted=false
    # If no presets specified, get all enabled from registry
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_configurator_preset_get_all_enabled)
    fi

    for preset in "${presets[@]}"; do
        local varname
        for varname in $(nds_configurator_preset_get_active_vars "$preset"); do
            if ! nds_configurator_var_validate "$varname" 2>/dev/null; then
                prompted=true
                break 2
            fi
        done
    done

    if [[ "$prompted" != true ]]; then
        return 0
    fi

    nds_configurator_wizard_intro
    section_header "Required fields"
    for preset in "${presets[@]}"; do
        nds_configurator_preset_prompt_errors "$preset"
    done
    new_section
}

nds_configurator_menu() {
    local presets=("$@")
    local last_status=""
    
    # If no presets specified, get all enabled from registry
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_configurator_preset_get_all_enabled)
    fi
    
    while true; do
        section_header "Configuration"
        [[ -n "$last_status" ]] && nds_ui_b "$last_status" && nds_ui_b ""
        nds_ui_b "Pick a category to fine-tune, or press X when ready to install."
        nds_ui_b ""
        
        local i=0
        for preset in "${presets[@]}"; do
            ((++i))
            nds_configurator_preset_display "$preset" "$i"
            nds_ui_b ""
        done
        
        # Inner loop for re-prompting without redrawing menu
        while true; do
            read -sr -n 1 -p "${NDS_UI_INDENT_B}Select category (1-$i or X when ready): " sel < /dev/tty
            echo
            
            # Handle empty input (just ENTER) - re-prompt
            if [[ -z "$sel" ]]; then
                continue
            fi
            
            if [[ "${sel,,}" == "x" ]]; then
                if ! nds_configurator_validate_all "${presets[@]}"; then
                    last_status="Configuration has errors — fix them before proceeding."
                    warn "$last_status"
                    break
                fi
                success "Configuration confirmed"
                nds_configurator_print_config_backup
                nds_configurator_confirm_config_saved || {
                    last_status="Copy the configuration export above, then confirm to continue."
                    warn "$last_status"
                    break
                }
                return 0
            elif [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 ]] && [[ "$sel" -le "$i" ]]; then
                local preset="${presets[$((sel-1))]}"

                while true; do
                    section_header "$(nds_configurator_preset_get_display "$preset") Configuration"
                    nds_ui_b "Press ENTER to keep current value, or type a new value"
                    nds_ui_b ""

                    nds_configurator_preset_prompt_all "$preset"

                    if nds_configurator_preset_validate "$preset" 2>/dev/null; then
                        last_status="$(nds_configurator_preset_get_display "$preset") updated"
                        success "$last_status"
                        break
                    fi
                done
                break
            else
                warn "Invalid selection"
                # Continue inner loop to re-prompt
            fi
        done
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
