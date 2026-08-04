# src/settings/system-vars

Owns the `NDS_*` process-environment bridge into the settings store.

| File | Responsibility |
|------|----------------|
| `env.sh` | Apply `NDS_*` → `CONFIG_DATA`, sync derived flake keys |

Settings-manager owns store/UI/presets. This module only maps environment ↔ store.
