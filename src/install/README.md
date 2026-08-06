# src/install

NixOS install pipeline — disk prep, secrets, `nixos-install`, backup bundle.

Loaded after action extension + settings init via framework bootstrap (`app/runtime/bootstrap_logic.sh`) with `nds_import_tree`.

## Layout

```
install/
  lib/                 Disk/system helpers
  logic/               Install + flake orchestration (*_logic.sh)
  ui/                  Confirm / display helpers
  nixcfg/
    logic/             configuration.nix builders + escape
    logic/blocks/      Block generators (boot, network, …)
  templates/           Disko + flake scaffold templates
  tests/               Colocated suites
```

## Related modules

- `src/git/` — SSH, clone, closure (calls `tools/` for gh)
- `src/bundle/` — Post-install backup zip + hooks
- `src/tools/` — Capability helpers (pkg, qr, gh, age, facter)
- `src/scripts/` — Target-machine CLIs (`nds-switch`, `nds-clean`, `nds-git-ssh`)
