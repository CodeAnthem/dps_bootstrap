# classicConfig

Builds a **classic `/etc/nixos/configuration.nix`** for the `classicInstall` action (no flake).

## Layout

| Path | Role |
|------|------|
| `builder.sh` | Block registry, merge, `nds_nixcfg_write` |
| `blocks/region.sh` | Timezone, locale, keyboard |
| `blocks/network.sh` | Hostname, DHCP/static IP |
| `blocks/access.sh` | Admin user, sudo, SSH |
| `blocks/boot.sh` | systemd-boot / GRUB |
| `blocks/packages.sh` | Optional package list |
| `blocks/security.sh` | Firewall / hardening stubs |

## Usage (from an action)

```bash
nds_nixcfg_build_classic_auto
nds_nixcfg_write "$NDS_RUNTIME_DIR/config/configuration.nix"
```

`installFlake` and `remoteAction` do **not** use this package — the flake owns system config.

## Tests

`bootstrap/tests/suites/classicConfig.sh` writes to a temp dir only.
