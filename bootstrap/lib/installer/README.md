# installer

NixOS install pipeline: disk prep, hardware facts, flake staging, `nixos-install`.

| File | Role |
|------|------|
| `nixInstaller.sh` | `nds_nixinstall_auto`, `nds_nixos_install`, `nds_nixos_install_flake` |
| `install.sh` | `nixos-generate-config`, `nixos-install`, flake clone |
| `disk.sh` | GPT layout, LUKS partition naming (nvme-aware) |
| `encryption.sh` | LUKS setup |
| `filesystem.sh` | Mount `/mnt` |
| `machineFacts.sh` | `machine.nix` (LUKS UUID) — dynamic LUKS detection |
| `remoteUnlock.sh` | Initrd SSH for remote unlock |
| `preflight.sh` | Disk / nix / network / SSH checks, disko auto-detect |
| `secrets.sh` | LUKS key backup prompt |

Used by `installFlake`, `classicInstall`, and `remoteAction` (fallback).
