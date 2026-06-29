# security

Install-time cryptographic helpers — not part of the interactive UI.

| File | Role |
|------|------|
| `crypto.sh` | LUKS key generation (`generate_key_hex`), SSH/Age keypairs, passphrases |

Used by `setup/disk.sh` and the installer encryption path.  
For masking secret fields in the configurator menu, see `configurator/inputs/primitive/secret.sh` (`display_secret`).
