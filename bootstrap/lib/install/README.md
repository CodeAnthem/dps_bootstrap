# lib/install

NixOS install pipeline — disk prep, secrets, `nixos-install`, backup bundle.

Loaded by `load.sh` in **dependency order** (via `nds_install_load` in `lib/load.sh`).

## Layout

```
install/
  load.sh              Explicit module order
  context.sh           _nixinstall_gather_context (single CONFIG_DATA read)
  disk-prep.sh         nds_nixinstall_auto (partition/mount/hardware)
  disk.sh              Partition layout (NDS built-in)
  filesystem.sh        Mount /mnt
  encryption.sh        LUKS secrets + format
  disko.sh             Disko template apply
  access.sh            Admin password → runtime secrets
  remoteUnlock.sh      Initrd SSH host keys on /mnt
  secrets.sh           List runtime secret files
  boot.sh              UEFI boot entry registration
  machineFacts.sh      LUKS UUID / machine metadata for flakes
  preflight.sh         Pre-install checks (nix, disk, flake build)
  install.sh           nixos-install, hardware gen, flake staging
  bundle/              Post-install backup zip + quickstart
  sops.sh              Age key enrollment
  partitionTools.sh    Public partition API (disko from config)
  templates/
    disko/default.nix       Disko layout template
    scaffold/*.nix.tmpl     Flake host scaffold (tools/flake)
```

## Pipelines (`core/install/`)

| File | Entry |
|------|-------|
| `classic-pipeline.sh` | `nds_nixos_install` |
| `flake-install-pipeline.sh` | `nds_nixos_install_flake` |
| `flake-pipeline.sh` | `nds_flake_install_prepare_and_verify`, `nds_flake_install_confirm` |

## Related tools

- `tools/install/detect.sh` — read-only disk state (loaded before install modules)
- `tools/git/` — SSH, clone, closure
- `tools/flake/` — flake prepare/scaffold
- `tools/nixWriter/` — configuration.nix generation
