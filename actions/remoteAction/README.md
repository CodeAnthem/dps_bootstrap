# Remote flake action

Use when your **leaf flake** ships install logic under `.nds/action.sh`. NDS clones the repo, sources the script, and runs it with full access to installer libraries.

If no remote action is found, NDS falls back to **installFlake**.

## Discovery order

1. `<flake>/.nds/action.sh` (preferred)
2. `<flake>/nds-action/setup.sh`
3. `<flake>/.nds/setup.sh`

## Remote action API

Your script is `source`d into the NDS shell. Define one or both:

### `remote_action_config` (optional)

Extra menu fields after the base disk + flake URL prompts:

```bash
remote_action_config() {
    PRESET_CONTEXT="myLeaf"
    nds_configurator_var_declare MY_FIELD \
        display="Example field" \
        input=string \
        default="value"
    PRESET_CONTEXT=""
}
```

NDS re-opens the menu after this runs.

### `remote_action_run` (required unless `action_setup` exists)

Install workflow — call NDS APIs:

```bash
remote_action_run() {
    nds_nixos_install_flake || return 1
    nds_secrets_offer_backup
    return 0
}
```

### Available APIs

| Function | Purpose |
|----------|---------|
| `nds_nixos_install_flake` | Full flake install pipeline |
| `nds_nixos_install` | Classic `/etc/nixos` install |
| `nds_nixinstall_auto` | Disk prep only |
| `nds_preflight_install` | Disk / nix / network checks |
| `nds_preflight_ssh_for_git` | SSH key reminder |
| `nds_secrets_offer_backup` | LUKS key copy prompt |
| `nds_install_log` | Append to `/tmp/nds_install.log` |

Environment: `NDS_FLAKE_*`, `NDS_DISK_STRATEGY`, `NDS_HARDWARE_PLACEMENT`, `NDS_RUNTIME_DIR`.

## Examples

- [thundercast/examples/nds-action/action.sh](https://github.com/CodeAnthem/thundercast/blob/master/examples/nds-action/action.sh) — generic template
- `dps_swarm/.nds/action.sh` — cluster role presets (private repo)

## Menu entry

Select **remoteAction** in the NDS menu (not installFlake) when your flake defines `.nds/action.sh`.
