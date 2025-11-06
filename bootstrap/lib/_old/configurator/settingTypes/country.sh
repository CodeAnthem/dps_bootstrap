#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2025-11-05
# Description:   SettingType - Country
# Feature:       Country selection with automatic timezone/locale/keyboard defaults
# ==================================================================================================

_country_promptHint() {
    echo "(US, DE, UK, FR, ES, IT, NL, etc. - 2-letter ISO code)"
}

_country_validate() {
    local value="$1"
    
    # ISO 3166-1 alpha-2 country code (2 uppercase letters)
    if [[ ! "$value" =~ ^[A-Za-z]{2}$ ]]; then
        return 1
    fi
    
    # Check if country is in our mapping
    if ! _country_getDefaults "${value,,}" &>/dev/null; then
        return 2  # Valid format but unknown country
    fi
    
    return 0
}

_country_normalize() {
    local value="$1"
    
    # Empty = skip defaults
    if [[ -z "$value" ]]; then
        echo ""
        return 0
    fi
    
    # Uppercase
    echo "${value^^}"
}

_country_errorCode() {
    local value="$1"
    
    # Check error type
    if [[ ! "$value" =~ ^[A-Za-z]{2}$ ]]; then
        echo "Invalid country code. Use 2-letter ISO code or empty to manually configure"
    else
        echo "Country code not in database. Use common codes: US, DE, CH, AT, UK, FR, ES, IT, NL, etc."
    fi
}

# Apply country defaults to region settings
_country_apply() {
    local country="$1"
    local defaults
    
    defaults=$(_country_getDefaults "$country")
    if [[ -z "$defaults" ]]; then
        return 1
    fi
    
    local timezone locale keyboard keyboard_variant
    IFS='|' read -r timezone locale keyboard keyboard_variant <<< "$defaults"
    
    # Apply defaults to region settings
    nds_cfg_apply_setting "TIMEZONE" "$timezone" "auto"
    nds_cfg_apply_setting "LOCALE" "$locale" "auto"
    nds_cfg_apply_setting "KEYBOARD_LAYOUT" "$keyboard" "auto"
    [[ -n "$keyboard_variant" ]] && nds_cfg_apply_setting "KEYBOARD_VARIANT" "$keyboard_variant" "auto"
    
    return 0
}

# =============================================================================
# COUNTRY DEFAULTS MAPPING
# =============================================================================

# Get default settings for a country
# Returns: timezone|locale|keyboard|keyboard_variant
_country_getDefaults() {
    local country="$1"
    
    case "${country,,}" in
        # North America
        us) echo "America/New_York|en_US.UTF-8|us|" ;;
        ca) echo "America/Toronto|en_CA.UTF-8|us|" ;;
        mx) echo "America/Mexico_City|es_MX.UTF-8|latam|" ;;
        
        # Western Europe
        de) echo "Europe/Berlin|de_DE.UTF-8|de|nodeadkeys" ;;
        fr) echo "Europe/Paris|fr_FR.UTF-8|fr|oss" ;;
        uk|gb) echo "Europe/London|en_GB.UTF-8|uk|" ;;
        es) echo "Europe/Madrid|es_ES.UTF-8|es|" ;;
        it) echo "Europe/Rome|it_IT.UTF-8|it|" ;;
        nl) echo "Europe/Amsterdam|nl_NL.UTF-8|us|intl" ;;
        be) echo "Europe/Brussels|fr_BE.UTF-8|be|" ;;
        ch) echo "Europe/Zurich|de_CH.UTF-8|ch|de_nodeadkeys" ;;
        at) echo "Europe/Vienna|de_AT.UTF-8|de|nodeadkeys" ;;
        pt) echo "Europe/Lisbon|pt_PT.UTF-8|pt|" ;;
        
        # Northern Europe
        se) echo "Europe/Stockholm|sv_SE.UTF-8|se|" ;;
        no) echo "Europe/Oslo|nb_NO.UTF-8|no|" ;;
        dk) echo "Europe/Copenhagen|da_DK.UTF-8|dk|" ;;
        fi) echo "Europe/Helsinki|fi_FI.UTF-8|fi|" ;;
        
        # Eastern Europe
        pl) echo "Europe/Warsaw|pl_PL.UTF-8|pl|" ;;
        cz) echo "Europe/Prague|cs_CZ.UTF-8|cz|" ;;
        ru) echo "Europe/Moscow|ru_RU.UTF-8|ru|" ;;
        ua) echo "Europe/Kiev|uk_UA.UTF-8|ua|" ;;
        
        # Asia
        jp) echo "Asia/Tokyo|ja_JP.UTF-8|jp|" ;;
        cn) echo "Asia/Shanghai|zh_CN.UTF-8|us|" ;;
        kr) echo "Asia/Seoul|ko_KR.UTF-8|kr|" ;;
        in) echo "Asia/Kolkata|en_IN.UTF-8|us|" ;;
        sg) echo "Asia/Singapore|en_SG.UTF-8|us|" ;;
        
        # Oceania
        au) echo "Australia/Sydney|en_AU.UTF-8|us|" ;;
        nz) echo "Pacific/Auckland|en_NZ.UTF-8|us|" ;;
        
        # South America
        br) echo "America/Sao_Paulo|pt_BR.UTF-8|br|abnt2" ;;
        ar) echo "America/Argentina/Buenos_Aires|es_AR.UTF-8|latam|" ;;
        cl) echo "America/Santiago|es_CL.UTF-8|latam|" ;;
        
        # Middle East
        il) echo "Asia/Jerusalem|he_IL.UTF-8|il|" ;;
        tr) echo "Europe/Istanbul|tr_TR.UTF-8|tr|" ;;
        ae) echo "Asia/Dubai|en_AE.UTF-8|us|" ;;
        
        # Africa
        za) echo "Africa/Johannesburg|en_ZA.UTF-8|us|" ;;
        
        *) return 1 ;;  # Unknown country
    esac
}

# Auto-register this settingType
nds_cfg_settingType_register "country"
