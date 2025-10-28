# Missing Implementations & TODO Items

## High Priority

### 1. Runtime Directory Management
**Status:** Partially implemented in main.sh  
**Issue:** Each action creates its own runtime dir. Should be global.  
**Solution Needed:**
- Move to bootstrap framework initialization
- Export `DPS_RUNTIME_DIR` globally
- Centralize cleanup handling
- All scripts should reference `$DPS_RUNTIME_DIR` instead of creating their own

### 2. Keyboard Variant Documentation
**Status:** Field exists but lacks proper documentation  
**What it is:** X11 keyboard layout variant/modification (e.g., dvorak, colemak, nodeadkeys)  
**Common values by layout:**
- **us**: dvorak, colemak, dvorak-intl, colemak-intl, altgr-intl
- **de**: nodeadkeys, neo, bone, dsb, dsb_qwertz
- **fr**: nodeadkeys, oss, latin9, bepo
- **ch**: fr, de, fr_nodeadkeys, de_nodeadkeys, fr_mac, de_mac
- **uk**: extd, intl, mac

**Default behavior:** Leave empty for standard layout  
**Action Required:** Already has help text, but could add country-specific defaults

### 3. Country-Specific Smart Defaults
**Status:** Implemented in region module  
**Issue:** User wants more prominent/better organized  
**Current behavior:**
- Setting COUNTRY triggers `region_set_country_defaults()`
- Auto-sets: timezone, locale, keyboard layout
- Supports: US, DE, UK, FR, ES, IT, NL, CH, AT, BE, SE, NO, DK, FI, PL, CZ

**Potential improvements:**
- Make COUNTRY field more prominent (show description of what it does)
- Add keyboard variant defaults per country
- Consider separating into its own "quick setup" step

## Medium Priority

### 4. Custom NixOS Configuration Merging
**Status:** Placeholder in deployVM/setup.sh  
**Location:** `actions/deployVM/nixosConfiguration/`  
**TODO:**
- Implement logic to merge custom .nix files with generated config
- Either use imports or merge nix expressions
- Consider using nix-instantiate or similar

### 5. Post-Install SSH Key Generation
**Status:** Not implemented  
**Needed:**
- Generate SSH keys for admin user during installation
- Save to mounted system at `/mnt/home/admin/.ssh/`
- Handle key type from access module config
- Set proper permissions (600 for private, 644 for public)

### 6. Deploy SSH Key Handling
**Status:** Field declared but not used  
**Fields:** `DEPLOY_SSH_KEY_PATH`, `GIT_REPO_URL`  
**TODO:**
- Copy deploy SSH key to mounted system
- Configure Git to use the deploy key
- Add to secrets collection output

### 7. Secrets Backup Workflow
**Status:** collect_and_show_secrets() shows locations but no backup mechanism  
**Needed:**
- Option to copy secrets to USB drive
- Option to save to network location
- Encrypted archive option
- QR code generation for LUKS key?

## Low Priority

### 8. Network Configuration for Static IP
**Status:** Module exists, NixOS config generation works  
**Issue:** May need testing with actual static IP setup  
**Fields:** IP_ADDRESS, GATEWAY, DNS_PRIMARY, DNS_SECONDARY

### 9. Module Integrity Checks
**Status:** Function exists in module.sh  
**Issue:** Not being called during module loading  
**TODO:** Call `nds_module_check_integrity()` during module initialization

### 10. Firewall Port Configuration
**Status:** Security module has TCP/UDP port fields  
**Issue:** Not being used in NixOS config generation  
**TODO:** Parse comma-separated port lists and add to firewall config

### 11. Additional Locales Handling
**Status:** Field exists in region module  
**Issue:** Not being added to NixOS config  
**TODO:** Parse LOCALE_EXTRA and add to i18n.extraLocaleSettings

### 12. Age Key Generation
**Status:** Mentioned in secrets collection  
**Issue:** Not being generated during installation  
**TODO:** Generate age keypair for sops-nix integration

### 13. Progress Indicator Enhancement
**Current:** Simple emoji status (⏳/✅/❌)  
**Could Add:**
- Spinner animation during long operations
- Progress bars for file operations
- Elapsed time display
- ETA estimation

### 14. Configuration Validation
**Status:** Basic validation in field normalization  
**Could Add:**
- Pre-flight disk space checks
- Network connectivity tests
- Bootloader compatibility checks
- Encryption key strength validation

### 15. Logging Improvements
**Current:** Console output only  
**Could Add:**
- Save full log to `/tmp/dps_install.log`
- Separate error log
- Structured logging (JSON format)
- Log levels (DEBUG, INFO, WARN, ERROR)

## Documentation Gaps

### 16. Module Development Guide
- How to create new modules
- Field declaration best practices
- NixOS config generation patterns
- Validation function patterns

### 17. Action Development Guide
- How to create new actions
- Required metadata fields
- Integration with module system
- Testing procedures

### 18. Keyboard Layout Reference
- Complete list of supported layouts
- Variant options per layout
- How to test keyboard configuration

### 19. Country Code Reference
- Complete list of supported country codes
- What each country auto-configures
- How to add new countries

## Architecture Improvements

### 20. Module Dependencies
**Not implemented:** Modules can't declare dependencies on other modules  
**Use case:** Deploy module depends on access module for user info  
**Solution:** Add `module_depends=("access" "network")` declaration

### 21. Conditional Fields
**Not implemented:** Fields can't be shown/hidden based on other field values  
**Use case:** ENCRYPTION_KEY_LENGTH only relevant when ENCRYPTION=true  
**Solution:** Add `show_if="ENCRYPTION=true"` to field declaration

### 22. Field Validation Dependencies
**Not implemented:** Can't validate based on multiple fields  
**Use case:** Static IP needs all fields (IP, gateway, DNS)  
**Solution:** Add module-level validation function that checks combinations

### 23. Configuration Presets
**Not implemented:** No way to save/load configuration sets  
**Use case:** "Development VM", "Production Server" presets  
**Solution:** Save config to JSON, load with --preset flag

## Testing Gaps

### 24. Automated Testing
- No unit tests for validation functions
- No integration tests for modules
- No end-to-end installation tests
- No CI/CD pipeline

### 25. Manual Test Procedures
- Need documented test cases
- Installation checklist
- Verification procedures
- Rollback procedures

---

## Recently Addressed

✅ **Module NixOS Config Generation** - All modules now use `nds_nixcfg_register()`  
✅ **Step Progress Indicators** - Added `step_start()`, `step_complete()`, `step_fail()`  
✅ **Installation Order** - Fixed config generation → disk prep → install sequence  
✅ **Hardware Config Generation** - Now only generates hardware-configuration.nix  
✅ **Tilde Path Expansion** - Deploy tools path supports `~/` notation  
✅ **Disk Cleanup** - Unmount and wipe existing partitions before partitioning  
✅ **Step Message Overlap** - Fixed line clearing in step_complete/step_fail
