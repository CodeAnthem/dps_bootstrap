# Deploy VM Setup Guide

**Deploy VM specific configuration and features.**

## 🎯 Deploy VM Characteristics

- **🔐 Encrypted by Default**: LUKS full-disk encryption
- **✍️ Write Access**: Full access to private NixOS repository
- **🛠️ Management Tools**: Complete deployment tooling
- **🌐 Network Flexible**: DHCP or static IP

## ⚙️ Deploy VM Configuration

### Required
- `DPS_HOSTNAME` - Deploy VM hostname

### Defaults (Deploy VM Specific)
```bash
DPS_ENCRYPTION="y"          # Security-first
DPS_NETWORK_METHOD="dhcp"   # Flexible deployment
DPS_ADMIN_USER="admin"
```

### Network Options

**DHCP (Default)**:
```bash
export DPS_NETWORK_METHOD="dhcp"
```

**Static IP**:
```bash
export DPS_NETWORK_METHOD="static"
export DPS_IP_ADDRESS="192.168.1.10"
export DPS_NETWORK_GATEWAY="192.168.1.1"
```

### Encryption Options
- `urandom` (default): Linux entropy
- `openssl-rand`: OpenSSL CSPRNG  
- `manual`: User-provided key

## 🔄 Deploy VM Workflow

1. **System Setup**: Partition disk, setup encryption
2. **NixOS Install**: Use `deployVM/configuration.nix`
3. **Tool Installation**: Deploy tools to `/opt/dps-tools/`
4. **Repository Access**: Configure write access to private repo

## 🏗️ Post-Installation Structure

```
Deploy VM (After Installation)
├── /etc/nixos/
│   ├── configuration.nix           # Deploy VM config
│   └── hardware-configuration.nix  # Generated hardware
├── /opt/dps-tools/                 # Deployment scripts
│   ├── cluster-deploy.sh
│   ├── node-manage.sh
│   └── secrets-sync.sh
└── /var/lib/dps-swarm/             # Private repo workspace
    └── [private repository]        # Write access
```

## 🛠️ Management Capabilities

### Deployment Commands
```bash
dps-deploy --template worker --count 3
dps-deploy --role gateway --hostname gateway-01
```

### Node Management
```bash
dps-manage update --all
dps-manage status --node worker-01
dps-manage restart --node gateway-01 --service nginx
```

### Secret Management
```bash
dps-secrets sync --all
dps-secrets update --secret database-password
dps-secrets rotate-keys
```

## 🔐 Security Features

### Access Control
- **Write Access**: Can modify infrastructure configs
- **SSH Keys**: Manage access to all nodes
- **SOPS Keys**: Control secret encryption

### Backup Strategy
**Critical Components**:
1. SOPS keys
2. SSH keys  
3. Configuration repository
4. LUKS encryption keys

## 🔍 Deploy VM Specific Troubleshooting

**Tool Permissions**: Ensure deployment tools have proper access
**Node Communication**: Verify SSH key distribution
**Secret Access**: Check SOPS key configuration

---

For general bootstrap info, see [README.md](README.md). For managed nodes, see [README_deployNode.md](README_deployNode.md).
