# Install from flake

Runs `nixos-install --flake` for any repository with `nixosConfigurations.<name>`.

**Your flake owns system config.** NDS only handles disk prep (optional), hardware facts (optional), staging the flake, and the install command. See [LIMITATIONS.md](../../LIMITATIONS.md).

## Menu fields

| Field | Purpose |
|-------|---------|
| `FLAKE_SOURCE` | `remote` (git clone) or `local` (copy from live system) |
| `FLAKE_HOST` | `nixosConfigurations` name for `nixos-install --flake` |
| `FLAKE_INSTALL_PATH` | Where the flake lives on the installed system |
| `FLAKE_HOST_DIR` | Subdirectory for per-host files (default `hosts/x86_64-linux`) |
| `DISK_PREP` | `nds` (default layout) or `skip` (you mounted `/mnt` — disko/advanced) |
| `HARDWARE_CONFIG` | `copy` (default) or `skip` (flake handles hardware) |

## Example preset

```bash
export NDS_FLAKE_SOURCE=remote
export NDS_FLAKE_REPO_URL=git+ssh://git@github.com/you/your-leaf.git
export NDS_FLAKE_HOST=my-server
export NDS_DISK_TARGET=/dev/vda
export NDS_ENCRYPTION=false
export NDS_DISK_PREP=nds
export NDS_HARDWARE_CONFIG=copy
sudo bash bootstrap/main.sh
```
