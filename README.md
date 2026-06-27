# dps_bootstrap

[![Version](https://img.shields.io/badge/version-4.0.1-0267c1?style=flat-square)](https://github.com/CodeAnthem/dps_bootstrap)
[![NixOS](https://img.shields.io/badge/NixOS-Live%20ISO-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)

**dps_bootstrap** (NDS) installs NixOS from a live ISO — disk layout, optional LUKS, hardware config, and `nixos-install --flake` for [dps_swarm](https://github.com/CodeAnthem/dps_swarm) cluster nodes.

```
NixOS ISO → dps_bootstrap → partition / mount → clone flake → nixos-install --flake
```

---

## Quickstart

### From live ISO (recommended)

1. Boot [NixOS minimal ISO](https://nixos.org/download/)
2. Optional: `passwd` and SSH in for comfort
3. Run:

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash
```

4. Select **nixosNode** (cluster node install)
5. Follow prompts — see [actions/nixosNode/README.md](actions/nixosNode/README.md)

### Local checkout

```bash
git clone git@github.com:CodeAnthem/dps_bootstrap.git
cd dps_bootstrap
sudo bash bootstrap/main.sh
```

### Auto-confirm (CI / scripting)

```bash
export NDS_AUTO_CONFIRM=true
sudo bash bootstrap/main.sh
```

---

## Actions

| Action | Purpose |
|--------|---------|
| **nixosNode** | Install a [dps_swarm](https://github.com/CodeAnthem/dps_swarm) host via flake |
| **deployVM** | Legacy management-hub install (classic `/etc/nixos` config) |
| **test** | Configurator / input tests (`DPS_TEST=true`) |

Cluster install guide: **[actions/nixosNode/README.md](actions/nixosNode/README.md)**

---

## What the nixosNode path does

1. Interactive configurator (disk, network, role)
2. Partition target disk (+ optional LUKS + initrd SSH for remote unlock)
3. Clone `dps_swarm` to `/mnt/opt/dps_swarm` (configurable)
4. Write `hardware-configuration.nix` (+ `machine.nix` when encrypted) into the host dir
5. `nixos-install --root /mnt --flake <checkout>#<host>`

The flake on disk is the source of truth — bootstrap does not generate `configuration.nix`.

---

## Configuration

Any configurator field can be preset via `DPS_*` env vars before launch:

```bash
export DPS_DISK_TARGET=/dev/vda
export DPS_ENCRYPTION=false
export DPS_HOSTNAME=control-toolkit
curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash
```

Debug logging: `export DEBUG=1`

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Root | Script re-execs with `sudo` if needed |
| Network | Clone bootstrap + dps_swarm during install |
| Git access | SSH key on ISO for private `dps_swarm` repo |
| Target disk | **Wiped** completely |
| sops hosts | Age key on target (`/etc/sops/age/keys.txt`) — not created by bootstrap yet |

---

## Architecture

| Path | Role |
|------|------|
| [`bootstrap/main.sh`](bootstrap/main.sh) | Entry, action discovery |
| [`bootstrap/lib/installation.sh`](bootstrap/lib/installation.sh) | Loads nixInstaller stack |
| [`bootstrap/lib/nixInstaller/`](bootstrap/lib/nixInstaller/) | Disk, LUKS, flake install |
| [`actions/nixosNode/`](actions/nixosNode/) | dps_swarm cluster node action |

Details: [bootstrap/README.md](bootstrap/README.md)

---

## Related

- [dps_swarm](https://github.com/CodeAnthem/dps_swarm) — cluster flake
- [Thundercast](https://github.com/CodeAnthem/thundercast) — infra modules
- [ThunderCore](https://github.com/CodeAnthem/thundercore) — compose framework
