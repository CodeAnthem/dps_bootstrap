#!/usr/bin/env bash
# ==================================================================================================
# NDS - App UI: action selection menu
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================

# Description: Interactive action picker (env path handled in runtime logic).
# Returns:
# - 0 with NDS_CURRENT_ACTION set; exits 130 on abort
nds_app_ui_select_action() {
    nds_ui_section_header "Choose an action"
    nds_ui_b ""
    nds_ui_choice_row "0" "Abort" "Exit the script"
    nds_ui_b ""

    local i=1 action_name
    for action_name in "${NDS_ACTION_NAMES[@]}"; do
        nds_ui_choice_row "$i" "$action_name" "${NDS_ACTION_DATA[${action_name}_description]}"
        ((i++))
    done
    nds_ui_b ""

    local choice max_choice="${#NDS_ACTION_NAMES[@]}"
    local prompt
    prompt="$(nds_ui_numbered_prompt 0 "$max_choice")"
    while true; do
        if choice=$(nds_ui_read_menu_digit "$prompt" 0 "$max_choice"); then
            [[ "$choice" == "0" ]] && { nds_ui_b "Operation aborted"; exit 130; }
            NDS_CURRENT_ACTION="${NDS_ACTION_NAMES[$((choice - 1))]}"
            return 0
        fi
        nds_ui_b "Invalid selection. Choose 0-${max_choice}"
    done
}
