# Actions

NDS discovers subdirectories here that provide `action_config()` and `action_setup()` in `setup.sh`.

## Production

| Action | Description |
|--------|-------------|
| [installFlake](installFlake/README.md) | `nixos-install --flake` from a remote Git repo or a local directory |

## Development only

| Action | Description |
|--------|-------------|
| [test](test/README.md) | Configurator input tests — visible when `NDS_TEST=true` |

## Archived

Cluster-specific and classic-config actions moved to [`_CleanupLater/`](../_CleanupLater/) (`deployVM`, `nixosNode`). New installs should use **installFlake** only.
