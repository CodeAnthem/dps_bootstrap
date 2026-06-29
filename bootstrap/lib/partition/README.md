# partition

Disk strategies: NDS manual GPT, Disko, or defer to flake (`DISK_STRATEGY`).

| File | Role |
|------|------|
| `partitionTools.sh` | Public API |
| `manual.sh` | parted/mkfs fast path |
| `disko.sh` | `nix run disko` integration |
| `detect.sh` | Disk state detection |
| `compat.sh` | Configurator shims |
| `templates/default.nix` | Built-in Disko template |
