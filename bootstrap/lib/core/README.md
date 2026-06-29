# core

NDS backbone — module loading and session runtime. No console menus or prompts here.

| File | Role |
|------|------|
| `import.sh` | `nds_import_*`, `nds_bootstrap_load_libs` orchestration |
| `runtime.sh` | `NDS_RUNTIME_DIR`, `/tmp/nds_install.log` |

User-facing output and prompts live in [`../ui/`](../ui/).  
Install-time key generation lives in [`../security/`](../security/).
