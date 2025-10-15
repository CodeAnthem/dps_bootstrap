# DPS Bootstrap One-liner Commands

## Recommended One-liner (with error handling)

```bash
# Download and verify, then execute
curl -fsSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/bootstrap.sh -o /tmp/bootstrap_temp.sh && \
bash -n /tmp/bootstrap_temp.sh && \
bash /tmp/bootstrap_temp.sh
```

## Alternative: Direct execution (less safe)

```bash
# Direct execution (original approach)
curl -sSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/bootstrap.sh | bash
```

## Manual verification approach

```bash
# 1. Download the script
curl -fsSL https://raw.githubusercontent.com/codeAnthem/dps_bootstrap/main/bootstrap.sh -o bootstrap.sh

# 2. Verify file size (should be ~6KB+)
ls -la bootstrap.sh

# 3. Check first and last lines
head -n 5 bootstrap.sh
tail -n 5 bootstrap.sh

# 4. Syntax check
bash -n bootstrap.sh

# 5. Execute if all looks good
bash bootstrap.sh
```

## Flags explanation:
- `-f` : Fail silently on HTTP errors (4xx, 5xx)
- `-s` : Silent mode (no progress bar)
- `-S` : Show errors even in silent mode  
- `-L` : Follow redirects
- `-o` : Output to file instead of stdout

## What the script does automatically:
1. Detects if running from one-liner vs local file
2. Clones full repository to `/tmp/dps_bootstrap/` if needed
3. Re-executes itself from proper location with all lib files
4. Provides interactive mode selection (Deploy VM vs Managed Node)
