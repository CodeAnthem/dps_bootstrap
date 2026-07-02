#!/usr/bin/env bash
# ==================================================================================================
# NDS - Quick setup preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-07-02
# ==================================================================================================

quick_defaults() {
    nds_cfg_set QUICK_COUNTRY ""
}

quick_configure() {
    nds_cfg_section_title "Quick Setup"
    nds_cfg_ask_country QUICK_COUNTRY "Country (quick setup)"
}

quick_summary() {
    local c
    c=$(nds_cfg_get QUICK_COUNTRY)
    if [[ -n "$c" ]]; then
        nds_cfg_summary_row "Country" "$c"
    else
        nds_cfg_summary_row "Country" "(manual region setup)"
    fi
}

quick_validate() {
    return 0
}

NDS_PRESET_PRIORITY=1
NDS_PRESET_DISPLAY="Quick Setup"
