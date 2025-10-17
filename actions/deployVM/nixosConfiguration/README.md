# Deploy VM NixOS Configuration

**NixOS configuration details for Deploy VM systems.**

## 📁 Configuration Files

```
deployVM/
├── configuration.nix           # Main Deploy VM config
├── hardware-template.nix       # Hardware template
└── README.md                   # This documentation
```

## 🔧 Core Features

### System Packages
```nix
environment.systemPackages = with pkgs; [
  # Development
  git gh vim
  
  # System utilities  
  htop curl wget jq
  
  # Container tools
  docker docker-compose
  
  # Deployment tools
  terraform ansible kubectl helm sops age
];
```

### System Services

**Docker Runtime**:
```nix
virtualisation.docker = {
  enable = true;
  enableOnBoot = true;
  autoPrune.enable = true;
};
```

**SSH Server**:
```nix
services.openssh = {
  enable = true;
  settings.PasswordAuthentication = false;
  openFirewall = true;
};
```

**Monitoring**:
```nix
services.prometheus.exporters.node.enable = true;
```

### User Configuration

**Admin User**:
```nix
users.users.admin = {
  isNormalUser = true;
  extraGroups = [ "wheel" "docker" ];
  openssh.authorizedKeys.keys = [
    # SSH keys from SOPS or configuration
  ];
};
```

## 🌐 Network Configuration

### DHCP Setup
```nix
networking = {
  hostName = "deploy-01";  # Set during installation
  useDHCP = true;
  firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };
};
```

### Static IP Setup
```nix
networking = {
  hostName = "deploy-01";
  useDHCP = false;
  interfaces.eth0.ipv4.addresses = [{
    address = "192.168.1.10";  # Set during installation
    prefixLength = 24;
  }];
  defaultGateway = "192.168.1.1";
  nameservers = [ "1.1.1.1" "1.0.0.1" ];
};
```

## 🔐 Security Configuration

### LUKS Encryption
```nix
boot.initrd.luks.devices.root = {
  device = "/dev/disk/by-uuid/...";  # Set during installation
  preLVM = true;
};
```

### SOPS Integration
```nix
sops = {
  defaultSopsFile = /etc/nixos/secrets/secrets.yaml;
  secrets = {
    github-token.owner = "admin";
    ssh-deploy-key = {
      owner = "admin";
      path = "/home/admin/.ssh/deploy_key";
    };
  };
};
```

## 🛠️ Tool Integration

### Deployment Services
```nix
systemd.services.dps-deploy = {
  description = "DPS Deployment Service";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "/opt/dps-tools/cluster-deploy.sh";
    User = "admin";
  };
};
```

### Tool Installation
```nix
environment.etc."dps-tools/cluster-deploy.sh" = {
  source = /path/to/cluster-deploy.sh;
  mode = "0755";
};
```

## 🔄 System Maintenance

### Auto Updates
```nix
systemd.services.nixos-auto-update = {
  serviceConfig.ExecStart = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade";
};

systemd.timers.nixos-auto-update = {
  timerConfig.OnCalendar = "weekly";
};
```

### Garbage Collection
```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

## 📊 Monitoring

### System Metrics
```nix
services.prometheus = {
  enable = true;
  scrapeConfigs = [{
    job_name = "deploy-vm";
    static_configs = [{ targets = [ "localhost:9100" ]; }];
  }];
};
```

### Log Management
```nix
services.journald.extraConfig = ''
  SystemMaxUse=1G
  MaxRetentionSec=1month
'';
```

## ⚙️ Performance Tuning

**System Optimization**:
```nix
boot.kernel.sysctl = {
  "vm.swappiness" = 10;
  "net.core.rmem_max" = 134217728;
};

services.fstrim.enable = true;  # SSD optimization
powerManagement.cpuFreqGovernor = "performance";
```

---

For Deploy VM setup guide, see [../bootstrap/README_deployVM.md](../bootstrap/README_deployVM.md).
