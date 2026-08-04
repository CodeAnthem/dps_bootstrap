# src/install

NixOS install pipeline — disk prep, secrets, `nixos-install`, backup bundle.

Loaded by `nds_install_load` from `src/app/bootstrap.sh` (after action extension + settings init).

## Layout

```
install/
  load.sh              Explicit module order
  detect.sh            Read-only disk state
  nix-store.sh         Store free-space helpers
  context.sh           _install_gather_context (single CONFIG_DATA read)
  disk-prep.sh         nds_install_auto (partition/mount/hardware)
  disk.sh              Partition layout (NDS built-in)
  filesystem.sh        Mount /mnt
  encryption.sh        LUKS secrets + format
  disko.sh             Disko template apply
  access.sh            Admin password → runtime secrets
  remoteUnlock.sh      Initrd SSH host keys on /mnt
  secrets.sh           List runtime secret files
  boot.sh              UEFI boot entry registration
  machineFacts.sh      Mounts / machine metadata for flakes
  hostStructure.sh     Committed mounts.nix / boot.nix helpers
  preflight.sh         Pre-install checks (nix, disk, flake build)
  install.sh           nixos-install, hardware gen, flake staging
  classic-pipeline.sh  nds_nixos_install
  flake-pipeline.sh    prepare/verify/confirm for installFlake
  flake-install-pipeline.sh  nds_nixos_install_flake
  bundle/              Post-install backup zip + quickstart
  sops.sh              Age key enrollment
  partitionTools.sh    Public partition API (disko from config)
  templates/
    disko/default.nix       Disko layout template
    scaffold/*.nix.tmpl     Flake host scaffold
```

## Related modules

- `src/git/` — SSH, clone, closure (framework-integrated)
- `src/git/lib/` — argument-driven URL helpers
- `src/install/flake/` — flake prepare/scaffold
- `src/install/nixcfg/` — configuration.nix generation
- `src/tools/` — nds-switch / nds-clean / nds-git-ssh (target machine)
