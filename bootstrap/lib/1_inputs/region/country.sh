#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-10-28
# Description:   Input Handler - Country Selection
# Feature:       Country selection with automatic timezone/locale/keyboard defaults
# ==================================================================================================

# =============================================================================
# COUNTRY INPUT
# =============================================================================

prompt_hint_country() {
    echo "(US, DE, UK, FR, ES, IT, NL, etc. - 2-letter ISO code)"
}

validate_country() {
    local value="$1"
    
    # ISO 3166-1 alpha-2 country code (2 uppercase letters)
    if [[ ! "$value" =~ ^[A-Z]{2}$ ]]; then
        return 1
    fi
    
    # Check if country is in our mapping
    if ! get_country_defaults "$value" &>/dev/null; then
        return 2  # Valid format but unknown country
    fi
    
    return 0
}

normalize_country() {
    local value="$1"
    # Uppercase
    echo "${value^^}"
}

error_msg_country() {
    local value="$1"
    local code="${2:-0}"
    
    case $code in
        2)
            echo "Country code not in database. Use common codes: US, DE, UK, FR, ES, IT, NL, CH, AT, etc."
            ;;
        *)
            echo "Invalid country code. Use 2-letter ISO code (e.g., US, DE, UK)"
            ;;
    esac
}

# =============================================================================
# COUNTRY DEFAULTS MAPPING
# =============================================================================

# Get default settings for a country
# Returns: timezone|locale|keyboard
get_country_defaults() {
    local country="$1"
    
    case "$country" in
        # North America
        US) echo "America/New_York|en_US.UTF-8|us" ;;
        CA) echo "America/Toronto|en_CA.UTF-8|us" ;;
        MX) echo "America/Mexico_City|es_MX.UTF-8|latam" ;;
        
        # Western Europe
        DE) echo "Europe/Berlin|de_DE.UTF-8|de" ;;
        FR) echo "Europe/Paris|fr_FR.UTF-8|fr" ;;
        UK|GB) echo "Europe/London|en_GB.UTF-8|uk" ;;
        ES) echo "Europe/Madrid|es_ES.UTF-8|es" ;;
        IT) echo "Europe/Rome|it_IT.UTF-8|it" ;;
        NL) echo "Europe/Amsterdam|nl_NL.UTF-8|us" ;;
        BE) echo "Europe/Brussels|fr_BE.UTF-8|be" ;;
        CH) echo "Europe/Zurich|de_CH.UTF-8|ch" ;;
        AT) echo "Europe/Vienna|de_AT.UTF-8|de" ;;
        PT) echo "Europe/Lisbon|pt_PT.UTF-8|pt" ;;
        
        # Northern Europe
        SE) echo "Europe/Stockholm|sv_SE.UTF-8|se" ;;
        NO) echo "Europe/Oslo|nb_NO.UTF-8|no" ;;
        DK) echo "Europe/Copenhagen|da_DK.UTF-8|dk" ;;
        FI) echo "Europe/Helsinki|fi_FI.UTF-8|fi" ;;
        
        # Eastern Europe
        PL) echo "Europe/Warsaw|pl_PL.UTF-8|pl" ;;
        CZ) echo "Europe/Prague|cs_CZ.UTF-8|cz" ;;
        RU) echo "Europe/Moscow|ru_RU.UTF-8|ru" ;;
        UA) echo "Europe/Kiev|uk_UA.UTF-8|ua" ;;
        
        # Asia
        JP) echo "Asia/Tokyo|ja_JP.UTF-8|jp" ;;
        CN) echo "Asia/Shanghai|zh_CN.UTF-8|us" ;;
        KR) echo "Asia/Seoul|ko_KR.UTF-8|kr" ;;
        IN) echo "Asia/Kolkata|en_IN.UTF-8|us" ;;
        SG) echo "Asia/Singapore|en_SG.UTF-8|us" ;;
        
        # Oceania
        AU) echo "Australia/Sydney|en_AU.UTF-8|us" ;;
        NZ) echo "Pacific/Auckland|en_NZ.UTF-8|us" ;;
        
        # South America
        BR) echo "America/Sao_Paulo|pt_BR.UTF-8|br" ;;
        AR) echo "America/Argentina/Buenos_Aires|es_AR.UTF-8|latam" ;;
        CL) echo "America/Santiago|es_CL.UTF-8|latam" ;;
        
        # Middle East
        IL) echo "Asia/Jerusalem|he_IL.UTF-8|il" ;;
        TR) echo "Europe/Istanbul|tr_TR.UTF-8|tr" ;;
        AE) echo "Asia/Dubai|en_AE.UTF-8|us" ;;
        
        # Africa
        ZA) echo "Africa/Johannesburg|en_ZA.UTF-8|us" ;;
        
        *) return 1 ;;  # Unknown country
    esac
}

# Apply country defaults to region fields
apply_country_defaults() {
    local country="$1"
    local defaults
    
    defaults=$(get_country_defaults "$country")
    if [[ -z "$defaults" ]]; then
        return 1
    fi
    
    local timezone locale keyboard
    IFS='|' read -r timezone locale keyboard <<< "$defaults"
    
    # Set defaults for region module
    nds_config_set_default "region" "TIMEZONE" "$timezone"
    nds_config_set_default "region" "LOCALE_MAIN" "$locale"
    nds_config_set_default "region" "KEYBOARD_LAYOUT" "$keyboard"
    
    return 0
}
