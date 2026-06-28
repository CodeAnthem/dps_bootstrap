# Install from flake

Generic `nixos-install --flake` for any repository that defines `nixosConfigurations.<name>`.

## Source modes

| Mode | Set | Description |
|------|-----|-------------|
| **remote** | `FLAKE_REPO_URL` | `git clone` onto the target disk after partitioning |
| **local** | `FLAKE_LOCAL_PATH` | Copy a directory from the live environment (USB stick, extra disk) |

## Fields

| Field | Purpose |
|-------|---------|
| `FLAKE_HOST` | `nixosConfigurations` name passed to `nixos-install --flake` |
| `FLAKE_INSTALL_PATH` | Where the flake lives on the installed system (default `/mnt/opt/flake`) |
| `FLAKE_HOST_DIR` | Subdirectory for per-host files (default `hosts/x86_64-linux`) — `hardware-configuration.nix` is written here |

Your flake owns all system configuration. NDS only handles disk prep, optional LUKS, hardware facts, and the install command.

## Example env preset

```bash
export NDS_FLAKE_SOURCE=remote
export NDS_FLAKE_REPO_URL=git+ssh://git@github.com/you/your-leaf.git
export NDS_FLAKE_HOST=my-server
export NDS_DISK_TARGET=/dev/vda
export NDS_ENCRYPTION=false
sudo bash bootstrap/main.sh
```

See [README.md](../../README.md) for the full live-ISO walkthrough.
