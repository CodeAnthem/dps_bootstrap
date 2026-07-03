# Install from flake

Installs `nixosConfigurations.<host>` from your flake. NDS handles disk prep, hardware facts, and staging — your flake owns system config.

## Disk strategies

| Strategy | Who partitions |
|----------|----------------|
| `nds` | NDS — simple GPT + optional LUKS |
| `disko` | NDS runs Disko (template or `DISKO_CONFIG`) |
| `flake` | Your flake — mount `/mnt` first |

## Hardware placement

| Mode | Where hardware-configuration.nix lives |
|------|--------------------------------------|
| `host-dir` | `<flake>/hosts/.../<host>/` (gitignored) |
| `etc-nixos` | `/etc/nixos` + `--override-input hardware` |
| `skip` | Flake handles hardware |

## Menu fields

### Your flake

| Field | Purpose |
|-------|---------|
| `FLAKE_LOCATION` | Git URL or local path — source (`remote`/`local`) is auto-detected |
| `FLAKE_HOST` | `nixosConfigurations` name |
| `FLAKE_INSTALL_PATH` | Flake path on installed system |
| `FLAKE_HOST_DIR` | Host subtree (default `hosts/x86_64-linux`) |
| `FLAKE_HARDWARE_PLACEMENT` | `host-dir` \| `etc-nixos` \| `skip` |

Accepted flake locations: `https://…`, `ssh://…`, `git@host:owner/repo(.git)`, or a
filesystem path (`/…`, `./…`, `~/…`). `git@`/`ssh` and paths are auto-classified.

### Private repositories

When a remote flake isn't reachable anonymously, NDS detects it and offers, in-place:

- **SSH deploy key** — generates a key on the live system (if missing), prints the
  public key and the provider's deploy-key URL, switches the clone to SSH.
- **HTTPS token** — prompts for a read-only token; it is held **in memory only**
  (never written to config, disk, or the backup bundle) and the cloned repo's
  remote is scrubbed back to the clean URL.

For env-driven installs you can still set `NDS_FLAKE_REPO_URL` (git URL) or
`NDS_FLAKE_LOCAL_PATH` (path) directly; `FLAKE_SOURCE` is derived automatically.

### Disk (shared preset)

| Field | Purpose |
|-------|---------|
| `DISK_STRATEGY` | `nds` \| `disko` \| `flake` |
| `DISKO_CONFIG` | Optional path to disko `.nix` (when strategy is `disko`) |

## Example

```bash
export NDS_FLAKE_REPO_URL=git@github.com:you/your-leaf.git
export NDS_FLAKE_HOST=my-server
export NDS_DISK_STRATEGY=nds
export NDS_FLAKE_HARDWARE_PLACEMENT=host-dir
export NDS_DISK_TARGET=/dev/vda
export NDS_ENCRYPTION=false
sudo bash bootstrap/main.sh
```
