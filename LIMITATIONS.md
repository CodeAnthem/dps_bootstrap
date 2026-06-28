# Scope and limitations

NDS is intentionally narrow: **live-ISO install helper for an existing flake**. This page is honest about what that means.

---

## What NDS does today

| Step | Behavior |
|------|----------|
| Disk | **NDS-owned GPT layout** by default: EFI + root, optional LUKS (not disko) |
| Hardware | `nixos-generate-config --root /mnt` → `hardware-configuration.nix` |
| Flake | `git clone` or `cp` your repo onto the installed system |
| Host files | Copies `hardware-configuration.nix` into `<FLAKE_HOST_DIR>/<hostname>/` (can skip) |
| LUKS facts | Can write `machine.nix` with partition UUID when encryption is on and host dir exists |
| Install | `nixos-install --root /mnt --flake <path>#<host>` |

**NDS does not write timezone, locale, users, networking, or services into your flake.** The menu used to collect some of that for the removed classic-config path (`nixConfigBuilder`); **installFlake ignores those modules**. Configure everything in your flake.

---

## Does NDS fight your flake?

### Disko or custom partitioning in the flake

**Yes, by default.** NDS partitions with `parted` before `nixos-install`. If your flake uses **disko** (or any module that expects to own the disk during install), NDS layout can conflict.

**Mitigation today:** set **Disk preparation** to `skip` in the menu (`NDS_DISK_PREP=skip`). You must already have `/mnt` mounted the way your install expects. This is an advanced escape hatch — document your own disko/manual steps in your flake README.

**Not supported yet:** a first-class “flake owns disk” mode that runs `nixos-install` without NDS partitioning and lets disko run natively.

### Hardware-configuration.nix

**Default:** NDS generates it and copies it into your flake’s host directory on disk.

**Why:** Most leaf flakes (Thundercast-style) import `./hardware-configuration.nix` per host. The file is machine-specific and usually gitignored.

**Skip:** set **Hardware config** to `skip` (`NDS_HARDWARE_CONFIG=skip`) if your flake already ships a stub, uses `--override-input`, or generates hardware another way.

### Read-only Git access

Cloning a **read-only** deploy token is fine — NDS only needs fetch access. Writes happen on the **installed disk** (copying `hardware-configuration.nix` / `machine.nix` into the checkout there), not back to GitHub.

### Flake without a host directory

NDS creates `<FLAKE_HOST_DIR>/<hostname>/` if missing. Your `nixosConfigurations.<host>` must still know how to import that path. NDS does not scaffold a full Thundercore `nixosBuilder` host tree.

---

## Manual install without NDS (for comparison)

### Graphical installer

The GUI writes `/etc/nixos/configuration.nix` + `hardware-configuration.nix` and runs a classic install. **No flake** unless you switch to flake mode manually afterward.

### Manual flake install (common expert path)

```bash
# 1. Partition & mount yourself (or let disko run at install time — follow your flake’s docs)
# 2. Put flake on machine (clone to /mnt/etc/nixos or /mnt/opt/myflake)
git clone <url> /mnt/opt/myflake
cd /mnt/opt/myflake

# 3. Hardware facts (machine-specific, often gitignored per host)
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/opt/myflake/hosts/x86_64-linux/myhost/hardware-configuration.nix

# 4. Install
nixos-install --root /mnt --flake /mnt/opt/myflake#myhost
```

**Flake with no hardware file yet:** generate as above, or use `nixos-generate-config` into `/mnt/etc/nixos` and wire imports in your host module.

**Flake with hardware stub in git:** replace or override at install time with the generated file (what NDS automates).

---

## Do we solve every scenario?

**No.** Deliberately.

| Scenario | NDS today | Possible future |
|----------|-----------|-----------------|
| Leaf flake + NDS disk layout + host dir | Supported | — |
| Disko-owned disk | Conflicts unless `DISK_PREP=skip` | Native disko mode |
| Skip hardware copy | `HARDWARE_CONFIG=skip` | — |
| Generate flake / host from menu | Not supported | Separate tool or action |
| Apply timezone/network from menu to flake | Not supported (by design) | Would need flake-aware codegen |
| Classic `/etc/nixos` only | Removed (`_CleanupLater/deployVM`) | Out of scope |

A **flake scaffold** action (create `hosts/…`, stub `configuration.nix`, wire `nixosConfigurations`) is a different product surface. NDS should stay the **install runner**; codegen could be a sibling tool or optional action later.

---

## When to use NDS vs manual

| Use NDS | Use manual / your flake docs |
|---------|------------------------------|
| You want guided disk + LUKS + confirm gates | Your flake uses disko end-to-end |
| Repeatable installs via `NDS_*` exports | You already have a one-liner in your repo |
| Thundercast-style host dir + hardware drop | You need exotic partition schemes NDS doesn’t know |

If in doubt, read your flake’s install section first — NDS should complement it, not replace it.
