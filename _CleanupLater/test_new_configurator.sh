#!/usr/bin/env bash
# Quick test script for new configurator system
# This tests the new system WITHOUT running full bootstrap

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "=== Testing New Configurator System ==="
echo ""

# Source required libraries
echo "Loading libraries..."
source bootstrap/lib/logger.sh 2>/dev/null || echo -e "${YELLOW}Warning: logger.sh not found, using basic output${NC}"
source bootstrap/lib/ui.sh 2>/dev/null || {
    # Fallback console function if ui.sh missing
    console() { echo "$@"; }
    success() { echo -e "${GREEN}✅ $*${NC}"; }
    error() { echo -e "${RED}❌ $*${NC}"; }
    debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${YELLOW}[DEBUG] $*${NC}"; }
    section_header() { echo "=== $* ==="; }
}

# Source validators
echo "Loading validators..."
source bootstrap/lib/validators.sh || { echo -e "${RED}Failed to load validators.sh${NC}"; exit 1; }

# Source configurator engine
echo "Loading configurator engine..."
source bootstrap/lib/configurator.sh || { echo -e "${RED}Failed to load configurator.sh${NC}"; exit 1; }

# Source modules
echo "Loading modules..."
for module in bootstrap/lib/config_modules/*.sh; do
    echo "  - $(basename "$module")"
    source "$module" || { echo -e "${RED}Failed to load $module${NC}"; exit 1; }
done

echo ""
echo -e "${GREEN}✅ All libraries loaded successfully!${NC}"
echo ""

# Test 1: Module Registration
echo "Test 1: Checking module registration..."
if config_module_exists "network"; then
    echo -e "${GREEN}✅ Network module registered${NC}"
else
    echo -e "${RED}❌ Network module NOT registered${NC}"
    exit 1
fi

if config_module_exists "disk"; then
    echo -e "${GREEN}✅ Disk module registered${NC}"
else
    echo -e "${RED}❌ Disk module NOT registered${NC}"
    exit 1
fi

if config_module_exists "custom"; then
    echo -e "${GREEN}✅ Custom module registered${NC}"
else
    echo -e "${RED}❌ Custom module NOT registered${NC}"
    exit 1
fi

echo ""

# Test 2: Configuration Init
echo "Test 2: Initializing configuration..."
config_init "test_action" "network"
config_init "test_action" "disk"
config_init "test_action" "custom"
echo -e "${GREEN}✅ All modules initialized${NC}"
echo ""

# Test 3: Get/Set Values
echo "Test 3: Testing get/set operations..."
config_set "test_action" "network" "HOSTNAME" "test-host"
retrieved=$(config_get "test_action" "network" "HOSTNAME")
if [[ "$retrieved" == "test-host" ]]; then
    echo -e "${GREEN}✅ Get/Set working correctly${NC}"
else
    echo -e "${RED}❌ Get/Set failed: expected 'test-host', got '$retrieved'${NC}"
    exit 1
fi
echo ""

# Test 4: Validators
echo "Test 4: Testing validators..."
if validate_ip "192.168.1.1"; then
    echo -e "${GREEN}✅ IP validation working${NC}"
else
    echo -e "${RED}❌ IP validation failed${NC}"
    exit 1
fi

if validate_hostname "test-server"; then
    echo -e "${GREEN}✅ Hostname validation working${NC}"
else
    echo -e "${RED}❌ Hostname validation failed${NC}"
    exit 1
fi

if validate_disk_size "8G"; then
    echo -e "${GREEN}✅ Disk size validation working${NC}"
else
    echo -e "${RED}❌ Disk size validation failed${NC}"
    exit 1
fi

echo ""

# Test 5: Display Callbacks
echo "Test 5: Testing display callbacks..."
echo ""
config_display "test_action" "network"
echo ""
config_display "test_action" "disk"
echo ""
config_display "test_action" "custom"
echo ""
echo -e "${GREEN}✅ Display callbacks working${NC}"
echo ""

# Test 6: Metadata
echo "Test 6: Testing metadata storage..."
config_set_meta "test_action" "network" "NETWORK_METHOD" "options" "dhcp|static"
options=$(config_get_meta "test_action" "network" "NETWORK_METHOD" "options")
if [[ "$options" == "dhcp|static" ]]; then
    echo -e "${GREEN}✅ Metadata storage working${NC}"
else
    echo -e "${RED}❌ Metadata failed: expected 'dhcp|static', got '$options'${NC}"
    exit 1
fi
echo ""

# Summary
echo "============================================"
echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
echo "============================================"
echo ""
echo "The new configurator system is working correctly."
echo ""
echo "Next steps:"
echo "  1. Test the full workflow: ./start.sh"
echo "  2. Select 'Deploy VM' action"
echo "  3. Verify interactive configuration works"
echo "  4. Check validation messages"
echo ""
echo "If issues found, rollback with:"
echo "  cd bootstrap/lib"
echo "  rm -rf config_modules validators.sh configurator.sh"
echo "  mv PreviousConfiguration/* ."
echo "  rmdir PreviousConfiguration"
echo ""
