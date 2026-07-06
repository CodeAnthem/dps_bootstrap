#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-05
# Description:   Category menu — calls per-preset configure/summary/validate (no hook framework)
# ==================================================================================================

nds_configurator_prompt_errors() {
    local presets=("$@") preset fixed=false
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_configurator_preset_get_all_enabled)
    fi
    for preset in "${presets[@]}"; do
        if ! nds_config_preset_validate "$preset" 2>/dev/null; then
            fixed=true
            break
        fi
    done
    [[ "$fixed" == true ]] || return 0

    section_header "Required fields"
    for preset in "${presets[@]}"; do
        if ! nds_config_preset_validate "$preset" 2>/dev/null; then
            nds_config_preset_prompt_errors "$preset"
        fi
    done
}

nds_configurator_menu() {
    local presets=("$@") last_status=""
    if [[ ${#presets[@]} -eq 0 ]]; then
        readarray -t presets < <(nds_configurator_preset_get_all_enabled)
    fi

    while true; do
        section_header "Configuration"
        [[ -n "$last_status" ]] && nds_ui_b "$last_status" && nds_ui_b ""
        nds_ui_b "Pick a category to fine-tune, or press X when ready to install."
        nds_ui_b ""

        local i=0 preset
        for preset in "${presets[@]}"; do
            ((++i))
            nds_config_preset_summary "$preset" "$i"
            nds_ui_b ""
        done

        while true; do
            read -sr -n 1 -p "${NDS_UI_INDENT_B}Select category (1-$i or X when ready): " sel < /dev/tty
            echo
            [[ -z "$sel" ]] && continue

            if [[ "${sel,,}" == "x" ]]; then
                if ! nds_configurator_validate_all "${presets[@]}"; then
                    nds_configurator_prompt_errors "${presets[@]}"
                    if ! nds_configurator_validate_all "${presets[@]}"; then
                        last_status="Configuration has errors — complete the required fields above."
                        warn "$last_status"
                        break
                    fi
                    last_status="Required fields updated"
                    success "$last_status"
                    break
                fi
                success "Configuration confirmed"
                nds_configurator_print_config_backup
                nds_configurator_confirm_config_saved || {
                    last_status="Press Y to continue to installation review, or X to try again."
                    warn "$last_status"
                    break
                }
                return 0
            fi

            if [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 ]] && [[ "$sel" -le "$i" ]]; then
                preset="${presets[$((sel-1))]}"
                section_header "$(nds_configurator_preset_get_display "$preset") Configuration"
                nds_ui_b "Press ENTER to keep current value, or type a new value"
                nds_ui_b ""
                nds_config_preset_configure "$preset"
                if nds_config_preset_validate "$preset" 2>/dev/null; then
                    last_status="$(nds_configurator_preset_get_display "$preset") updated"
                    success "$last_status"
                else
                    last_status="$(nds_configurator_preset_get_display "$preset") has errors — fix before pressing X."
                    warn "$last_status"
                fi
                break
            fi
            warn "Invalid selection"
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
    nds_configurator_menu_or_skip "${presets[@]}"
}

# Description: Skip the category menu when NDS_SKIP_MENU or NDS_AUTO_CONFIRM is set
# and validation passes; otherwise run the interactive menu.
nds_configurator_menu_or_skip() {
    local presets=("$@")
    if nds_skip_menu NDS_SKIP_MENU; then
        if ! nds_configurator_validate_all "${presets[@]}"; then
            nds_configurator_prompt_errors "${presets[@]}"
            nds_configurator_validate_all "${presets[@]}" || return 1
        fi
        log "Configuration complete (menu skipped)"
        nds_configurator_print_config_backup
        if nds_skip_menu NDS_CONFIG_CONFIRM_SKIP; then
            return 0
        fi
        nds_configurator_confirm_config_saved || return 1
        return 0
    fi
    nds_configurator_menu "${presets[@]}"
}
