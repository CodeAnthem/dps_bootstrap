#!/usr/bin/env bash
# Verify downloaded bootstrap script integrity

EXPECTED_SIZE=6000  # Approximate size in bytes
EXPECTED_PATTERN="DPS Bootstrap - NixOS Deployment System"

verify_bootstrap() {
    local file="$1"
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "❌ File not found: $file"
        return 1
    fi
    
    # Check file size (rough check)
    local size=$(wc -c < "$file")
    if [[ $size -lt 3000 ]]; then
        echo "❌ File too small ($size bytes), likely incomplete"
        return 1
    fi
    
    # Check for expected content
    if ! grep -q "$EXPECTED_PATTERN" "$file"; then
        echo "❌ File doesn't contain expected pattern"
        return 1
    fi
    
    # Check for script end
    if ! tail -n 5 "$file" | grep -q "main.*@"; then
        echo "❌ Script appears incomplete (missing main execution)"
        return 1
    fi
    
    echo "✅ File appears complete and valid"
    return 0
}

# Usage: verify_bootstrap downloaded_file.sh
