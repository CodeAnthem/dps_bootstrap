# Nix Deploy System (NDS)

[![Version](https://img.shields.io/badge/version-4.0.1-0267c1?style=flat-square)](https://github.com/CodeAnthem/dps_bootstrap)
[![NixOS](https://img.shields.io/badge/NixOS-Live%20ISO-5277C3?style=flat-square&logo=nixos&logoColor=white)](https://nixos.org)
[![ShellCheck](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/CodeAnthem/dps_bootstrap/actions/workflows/shellcheck.yml)

**NDS** is an interactive installer for bare-metal and VM targets from the official **NixOS live ISO**. It partitions disks, optionally sets up LUKS, generates hardware configuration, and runs `nixos-install` — either from a **classic** generated `/etc/nixos` tree or from a **flake** checkout you point it at.

It is a **standalone bootstrap tool**, not tied to one cluster or one GitHub org. It works with any NixOS flake that exposes `nixosConfigurations.<name>` — including [Thundercast](https://github.com/CodeAnthem/thundercast) leaf consumers and your own private repos.

```
Live ISO → configure (menu) → disk prep → nixos-install
                              ↳ classic config   OR   --flake <url>#<host>
```

---

## What it does

| Step | Description |
|------|-------------|
| **Configure** | Validated prompts for disk, network, hostname, encryption, and action-specific options |
| **Backup-friendly export** | After you confirm settings, prints `export DPS_*="..."` lines so you can replay the same install |
| **Disk** | Partition, optional LUKS, mount `/mnt` |
| **Hardware** | `nixos-generate-config` → host directory or `/etc/nixos` |
| **Install** | `nixos-install` (classic) or `nixos-install --flake` (flake action) |

**Actions** (chosen at startup):

| Action | Use when |
|--------|----------|
| **nixosNode** | Your system is defined in a **flake** (`hosts/`, `nixosConfigurations`) |
| **deployVM** | You want a **generated** `configuration.nix` on the target (management / jump box) |

---

## Trust before you run

Do not pipe random scripts into `bash` without looking. This repo is open source — verify first:

1. **Read** [`start.sh`](start.sh) (~200 lines): clones this repo to `/tmp/dps_bootstrap`, optionally warns on untracked files, then runs `bootstrap/main.sh`.
2. **Clone only** (no install):  
   `curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash -s -- --no-exec`  
   Inspect `/tmp/dps_bootstrap`, then run `sudo bash /tmp/dps_bootstrap/bootstrap/main.sh` yourself.
3. **Or clone with git** and run `sudo bash bootstrap/main.sh` from your checkout.
4. **CI**: Shell scripts are linted with [ShellCheck](https://www.shellcheck.net/) on every push — see badge above.

Secrets (LUKS keys, generated passwords) are written to a temporary runtime directory and called out at the end of install — **copy them before reboot**.

---

## Quickstart

### 1. Boot the live ISO

Download the [NixOS minimal ISO](https://nixos.org/download/), boot the target machine or VM, and log in as **root** on the console (no password on first login).

### 2. Enable SSH (recommended)

The live environment ships with **OpenSSH enabled**. Root cannot log in over SSH until you set a password:

```bash
passwd
```

Show the machine's IP address:

```bash
ip -4 a
```

Pick the address on your LAN (often `eth0` or `enp0s3`, e.g. `192.168.1.50`).

**From Linux or macOS:**

```bash
ssh root@192.168.1.50
```

**From Windows (PowerShell or Command Prompt)** — OpenSSH client is built into Windows 10/11:

```powershell
ssh root@192.168.1.50
```

Accept the host key on first connect, then enter the password you set with `passwd`.

### 3. Run the bootstrapper

**One-liner** (downloads to `/tmp`, then starts the menu):

```bash
curl -sSL https://raw.githubusercontent.com/CodeAnthem/dps_bootstrap/main/start.sh | bash
```

**From a git checkout:**

```bash
git clone https://github.com/CodeAnthem/dps_bootstrap.git
cd dps_bootstrap
sudo bash bootstrap/main.sh
```

### 4. Configure and install

1. Select an **action** (`nixosNode` for flake-based hosts, `deployVM` for classic config).
2. Walk through the **configuration menu** (disk, network, …).
3. Press **X** when done — the installer prints your **`DPS_*` export lines**; save them.
4. Confirm and let the installer partition the disk and run `nixos-install`.
5. Back up **runtime secrets** if prompted, then reboot.

### Replay the same settings later

Paste the exported lines into your shell before starting the bootstrapper:

```bash
export DPS_DISK_TARGET=/dev/vda
export DPS_ENCRYPTION=false
export DPS_HOSTNAME=my-server
# … remaining DPS_* lines from the backup block …
sudo bash bootstrap/main.sh
```

Or set `NDS_AUTO_CONFIRM=true` to skip yes/no prompts when automating.

---

## Configuration reference

| Mechanism | Purpose |
|-----------|---------|
| `DPS_<FIELD>` | Preset any configurator field before launch (shown in the backup export) |
| `NDS_AUTO_CONFIRM=true` | Skip confirmation prompts |
| `DEBUG=1` | Verbose logging |

Flake installs (`nixosNode`) additionally need network access to **clone your flake URL** (often `git+ssh://…` — load SSH keys on the live ISO first).

---

## Flake-based install (nixosNode)

For Thundercast-style leaf flakes ([Thundercast](https://github.com/CodeAnthem/thundercast) + your private `hosts/`):

- Set **flake Git URL** and **install path on disk** (default `/mnt/opt/<repo>`).
- Pick a **host name** that exists under `nixosConfigurations` in your flake.
- The bootstrapper clones the flake **after** mounting `/mnt`, writes `hardware-configuration.nix` into the host folder, and runs `nixos-install --flake <path>#<host>`.

Details: [actions/nixosNode/README.md](actions/nixosNode/README.md)

---

## Related projects

| Project | Role |
|---------|------|
| [ThunderCore](https://github.com/CodeAnthem/thundercore) | NixOS compose framework |
| [Thundercast](https://github.com/CodeAnthem/thundercast) | Public infra modules (gateways, workers, swarm, LUKS, …) |
| Your leaf flake | Private `hosts/`, secrets, cluster-specific modules |

NDS does not depend on any of these — it only needs a valid install target (classic config or flake).

---

## Develop

```bash
DEBUG=1 sudo bash bootstrap/main.sh

# Configurator tests
DPS_TEST=true sudo bash bootstrap/main.sh   # includes test action

# ShellCheck locally
shellcheck start.sh bootstrap/**/*.sh actions/**/*.sh
```

Technical notes for contributors: [bootstrap/README.md](bootstrap/README.md)
