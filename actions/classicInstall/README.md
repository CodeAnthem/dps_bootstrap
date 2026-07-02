# Classic install (no flake)

First NixOS install without a flake. NDS generates `/etc/nixos/configuration.nix` +
`hardware-configuration.nix` and runs `nixos-install`. You own nothing beforehand —
NDS asks the menu and builds a complete, bootable system.

## What you configure

Timezone, locales, keyboard, **network**, **admin user**, bootloader, **disk**, and
optional **LUKS2 encryption** (passphrase, USB keyfile, or both — plus initrd SSH
**remote unlock**).

## What NDS does

1. Partition the target disk (and set up LUKS2 if encryption is enabled)
2. Generate `configuration.nix` + `hardware-configuration.nix`
3. Run `nixos-install`
4. Build an install backup zip (with a personalized `NDS_QUICK_START.md`), then reboot

The backup zip lands in `/home/nixos/` and contains everything below, personalized to
the machine you just installed. Copy it off the box **before** rebooting.

---

## After install

### First login

- **Admin user:** the name you chose (default `admin`).
- **Admin password:** if you left auto-generate on, it's in the backup zip at
  `secrets/admin_password.txt`; otherwise it's the password you set during configuration.
- **SSH from your PC:**

```bash
ssh admin@<machine-ip>
```

- Password login is enabled by default — use the password above. If you configured an
  SSH key with password login off, use your key instead.
- **Console login** works with the same admin user + password.

Change the admin password after first login:

```bash
passwd
```

---

## Remote unlock (initrd SSH)

When you enable **encryption → remote unlock**, NDS configures NixOS to start a tiny SSH
server **in the initrd** (early boot, before the disk is decrypted). You SSH in over the
network and enter the LUKS passphrase remotely, so the machine can boot without a physical
keyboard/console.

At boot:

- Initrd SSH listens on **port 22**, as user **root** (pubkey-only).
- With **DHCP** (default), the initrd requests its **own** lease, so its IP is often
  **not** the same one the fully-booted machine normally gets — check your router/DHCP
  server logs for the address that appears while the LUKS prompt is up. For a predictable,
  always-reachable address, pick a **static IP** for remote unlock.
- The **authorized key** is the public key you provided during configuration.
- The **initrd host key** is in the backup zip at `secrets/initrd_ssh_host_ed25519_key`.

### How the keys work

There are **two** separate keys — don't mix them up:

| Key | Who owns it | Job |
|-----|-------------|-----|
| **Host key** | The NixOS machine | Proves the initrd is really your machine (so your SSH client doesn't warn about a changed host key). NDS **generates this automatically** and puts it in the backup zip at `secrets/initrd_ssh_host_ed25519_key`. |
| **Authorized key** | **You** (your personal PC) | Authenticates *you*. You paste your PC's **public** key into the "Authorized SSH public key" prompt. Only clients holding the matching **private** key can log in. |

Initrd SSH is **pubkey-only** — there is no password login (unlike dropbear-with-password).
That's why the authorized key field is required: without it, nobody could connect. Logging
in and unlocking are **two steps** — the key gets you *into* the initrd, then you type the
**LUKS passphrase** to decrypt.

### Make a key on your personal PC

On the machine you'll connect **from** (Linux, macOS, Windows 10+, or WSL):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/nixosController
```

On Windows the path is e.g. `C:\Users\you\.ssh\nixosController`. Leave the passphrase empty
for unattended use, or set one for extra safety.

Then print the **public** key (note the `.pub`) and copy the whole line:

```bash
cat ~/.ssh/nixosController.pub
# Windows: type C:\Users\you\.ssh\nixosController.pub
```

It looks like:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... you@yourpc
```

Paste **that full line** into the "Authorized SSH public key" prompt.

> The `SHA256:...` line ssh-keygen prints is only a **fingerprint** (a hash for visual ID)
> — it is **not** the key and will not work.

### Connect and unlock

After the machine reboots and reaches the LUKS prompt, from your PC:

```bash
ssh -i ~/.ssh/nixosController root@<machine-ip>
# the passphrase prompt appears automatically; type it and the machine boots
```

The authorized key is wired with `command="systemctl default"`, so logging in drops you
**straight into the passphrase prompt** — no shell, no extra command to remember.

Initrd SSH logs in as **root** (a minimal early-boot environment) — not your admin user,
which only exists once the real system is booted.

### If your PC dies / recovery

The SSH key is a **convenience**, not the safety net — the safety net is the **LUKS
passphrase** (in the backup zip). You can always unlock at the physical console / VM
console / IPMI-KVM by typing the passphrase directly.

To avoid losing remote access:

- **Back up your private key** (`~/.ssh/nixosController`) somewhere safe — encrypted USB or
  a password manager. Restore it on a new PC and you're back in.
- **Authorize a second machine** — the menu takes one key, but you can add more clients by
  editing `boot.initrd.network.ssh.authorizedKeys` in the generated config (or reinstalling
  with a different key).
