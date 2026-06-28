# Install from flake

See [ARCHITECTURE.md](../../ARCHITECTURE.md) for the full model (disk strategies, hardware placement, git pull).

## Menu fields

### Your flake

| Field | Purpose |
|-------|---------|
| `FLAKE_SOURCE` | `remote` (git clone) or `local` (copy from live system) |
| `FLAKE_HOST` | `nixosConfigurations` name |
| `FLAKE_INSTALL_PATH` | Flake path on installed system |
| `FLAKE_HOST_DIR` | Host subtree (default `hosts/x86_64-linux`) |
| `HARDWARE_PLACEMENT` | `host-dir` \| `etc-nixos` \| `skip` |

### Disk (shared preset)

| Field | Purpose |
|-------|---------|
| `DISK_STRATEGY` | `nds` \| `disko` \| `flake` |
| `DISKO_CONFIG` | Optional path to disko `.nix` (when strategy is `disko`) |

## Example

```bash
export NDS_FLAKE_SOURCE=remote
export NDS_FLAKE_REPO_URL=git+ssh://git@github.com/you/your-leaf.git
export NDS_FLAKE_HOST=my-server
export NDS_DISK_STRATEGY=nds
export NDS_HARDWARE_PLACEMENT=host-dir
export NDS_DISK_TARGET=/dev/vda
export NDS_ENCRYPTION=false
sudo bash bootstrap/main.sh
```
