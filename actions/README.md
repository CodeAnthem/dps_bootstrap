# Actions

NDS discovers subdirectories here that provide `action_config()` and `action_setup()` in `setup.sh`.

## Production

| Action | Description |
|--------|-------------|
| [classicInstall](classicInstall/) | No flake — generates `/etc/nixos/configuration.nix` + `nixos-install` |
| [installFlake](installFlake/README.md) | `nixos-install --flake` from remote Git or local path |
| [remoteAction](remoteAction/) | Clone flake and run `.nds/action.sh` if present, else installFlake |

## Development only

| Action | Description |
|--------|-------------|
| [test](test/README.md) | Self-tests (configurator, inputs, classicConfig) — `NDS_TEST=true` |

## Archived

Cluster-specific actions in [`_CleanupLater/`](../_CleanupLater/) (`deployVM`, `nixosNode`).
