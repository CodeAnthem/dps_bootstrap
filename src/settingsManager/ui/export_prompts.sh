#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings Manager UI: export / confirm / preset summary
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_CONFIG_CONFIRM_SKIP

# Description: Print changed-from-defaults export lines for the operator.
nds_cfg_print_backup() {
    local line count=0
    nds_ui_section_header "Configuration export"
    nds_ui_b "Only values changed from defaults (export NDS_*= lines)."
    nds_ui_b "Full scoped arrays + complete env are written in the install backup bundle."
    nds_ui_b ""
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        nds_ui_i "$line"
        count=$((count + 1))
    done < <(nds_cfg_export_modified)
    if [[ -n "${NDS_CURRENT_ACTION:-}" ]]; then
        nds_ui_i "export NDS_ACTION=\"${NDS_CURRENT_ACTION}\""
        count=$((count + 1))
    fi
    if [[ "$count" -eq 0 ]]; then
        nds_ui_i "# (no changes from defaults)"
    fi
    nds_ui_b ""
}

# Description: Confirm leaving settings menu into install review.
nds_cfg_confirm_saved() {
    if nds_skip_menu NDS_CONFIG_CONFIRM_SKIP; then
        log "Configuration review confirmation skipped"
        return 0
    fi
    nds_ask_user_to_proceed "Continue to installation review" || return 1
    return 0
}

# Description: Print a preset display header and optional summary hook.
# Arguments:
# - preset: <String> Preset id
# - number: <String|optional> Menu index prefix
nds_cfg_preset_summary() {
    local preset="$1" number="${2:-}"
    local display header fn
    display=$(nds_cfg_preset_get_display "$preset")
    header="${display}:"
    [[ -n "$number" ]] && header="$number. $header"
    nds_ui_h "$header"
    if fn="$(_nds_preset_hook_fn "$preset" summary)"; then
        "$fn"
    fi
}
