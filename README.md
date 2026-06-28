# Nix Deploy System (NDS)

[![Version](https://img.shields.io/badge/version-4.0.1-0267c1?style=flat-square)](https://github.com/CodeAnthem/dps_bootstrap)
[![NixOS](https://img.shields.io/badge/NixOS-Live%20ISO-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![ShellCheck](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml)

**NDS** is an interactive installer for bare-metal and VM targets from the official **NixOS live ISO**. It partitions disks, optionally sets up LUKS, places `hardware-configuration.nix` into your flake's host directory, and runs `nixos-install --flake`.

It is a **generic bootstrap tool**: it works with any flake that defines `nixosConfigurations.<name>`. Your flake owns all system configuration; NDS does not ship secrets or cluster-specific logic.

```
  NixOS live ISO
        │
        ▼
   configure (menu)
        │
        ▼
   disk prep ──► partition, optional LUKS, mount /mnt
        │
        ▼
   stage flake ──► remote git clone  OR  copy local directory
        │
        ▼
   nixos-install --flake <path>#<host>
```

See [TRUST.md](TRUST.md) before running remote one-liners.

---

## What it does

| Step | Description |
|------|-------------|
| **Configure** | Validated prompts for disk, network, encryption, and flake options |
| **Backup export** | After you confirm settings, prints `export NDS_*="..."` lines to replay the install |
| **Disk** | Partition, optional LUKS, mount `/mnt` |
| **Hardware** | `nixos-generate-config` → host directory inside your flake |
| **Install** | `nixos-install --flake <path>#<host>` |

## Actions

NDS ships one production action:

| Action | Purpose |
|--------|---------|
| **[installFlake](actions/installFlake/README.md)** | Install from a **remote** Git flake or a **local** flake directory on the live system |

Legacy cluster-specific actions (`deployVM`, `nixosNode`) live under [`_CleanupLater/`](_CleanupLater/) for reference only.

---

## Quickstart

### 1. Boot the live ISO

Download the [NixOS minimal ISO](https://nixos.org/download/), boot the target machine or VM, and log in as **root** on the console.

### 2. Enable SSH (recommended)

```bash
passwd          # required before root SSH login
ip -4 a         # note the LAN address, e.g. 192.168.1.50
```

```bash
ssh root@192.168.1.50
```

### 3. Run the bootstrapper

**One-liner** (clones to `/tmp`, then starts the menu):

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash
```

For a **fork or renamed repo**, set the Git URL before piping (there is no automatic self-reference at `curl | bash` time — see [TRUST.md](TRUST.md)):

```bash
export NDS_REPO_URL='https://github.com/you/your-repo.git'
curl -sSL https://raw.githubusercontent.com/you/your-repo/main/start.sh | bash
```

**Manual steps** (download the project yourself):

```bash
git clone https://github.com/CodeAnthem/dps_bootstrap.git
cd dps_bootstrap
sudo bash bootstrap/main.sh
```

When run from a checkout, `start.sh` detects `git remote.origin.url` — no hardcoded org required.

### 4. Configure and install

1. Select **installFlake**.
2. Choose **remote** (Git URL) or **local** (path on the live system).
3. Walk through disk, network, and flake fields in the menu.
4. Press **X** when done — save the printed **`NDS_*` export lines**.
5. Confirm — the installer erases the target disk and runs `nixos-install`.
6. Copy **runtime secrets** (LUKS key, if enabled), then reboot.

### Replay the same settings

```bash
export NDS_DISK_TARGET=/dev/vda
export NDS_ENCRYPTION=false
export NDS_FLAKE_HOST=my-server
export NDS_FLAKE_REPO_URL=git+ssh://git@github.com/you/your-leaf.git
# … remaining NDS_* lines from the backup block …
sudo bash bootstrap/main.sh
```

Or set `NDS_AUTO_CONFIRM=true` to skip yes/no prompts when automating.

---

## Configuration reference

| Mechanism | Purpose |
|-----------|---------|
| `NDS_<FIELD>` | Preset any configurator field before launch (mirrors the backup export) |
| `NDS_AUTO_CONFIRM=true` | Skip confirmation prompts |
| `NDS_REPO_URL` | Git remote for `start.sh` when not run from a checkout |
| `NDS_REPO_NAME` | Directory name under `/tmp` (default: basename of repo URL) |
| `DEBUG=1` | Verbose logging |

Common flake fields: `NDS_FLAKE_SOURCE`, `NDS_FLAKE_REPO_URL`, `NDS_FLAKE_LOCAL_PATH`, `NDS_FLAKE_INSTALL_PATH`, `NDS_FLAKE_HOST`, `NDS_FLAKE_HOST_DIR`.

Example preset file: [`config-example.sh`](config-example.sh).

Remote installs need network access to clone your flake (often `git+ssh://…` — load SSH keys on the live ISO first).

---

## Usage in your flake project

Point your leaf README at this repo for live-ISO installs. Example host preset (adjust names and URLs):

```bash
export NDS_FLAKE_SOURCE=remote
export NDS_FLAKE_REPO_URL=git+ssh://git@github.com/you/your-leaf.git
export NDS_FLAKE_HOST=controller
export NDS_FLAKE_INSTALL_PATH=/mnt/opt/your-leaf
export NDS_DISK_TARGET=/dev/vda
export NDS_ENCRYPTION=false
sudo bash bootstrap/main.sh
```

Your flake must expose `nixosConfigurations.<NDS_FLAKE_HOST>` and typically a `hosts/x86_64-linux/<host>/` tree for hardware facts (override with `NDS_FLAKE_HOST_DIR`).

---

## Develop

```bash
DEBUG=1 sudo bash bootstrap/main.sh

# Configurator tests (test action only when enabled)
NDS_TEST=true sudo bash bootstrap/main.sh

# ShellCheck is run in CI — no local install required
```

Contributor notes: [bootstrap/README.md](bootstrap/README.md)
