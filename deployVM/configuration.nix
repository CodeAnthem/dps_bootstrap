# DPS Deploy VM Configuration - Management and deployment tools
{ config, lib, pkgs, ... }:

{
  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable SSH with secure defaults
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
    };
  };

  # Users configuration
  users.users = {
    admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "docker" ];
      openssh.authorizedKeys.keys = [
        # SSH keys will be configured during bootstrap
      ];
    };
  };

  # Enable sudo without password for wheel group (Deploy VM convenience)
  security.sudo.wheelNeedsPassword = false;

  # Deploy VM specific system packages
  environment.systemPackages = with pkgs; [
    # Core system tools
    git
    vim
    neovim
    htop
    btop
    tree
    curl
    wget
    jq
    yq
    bat
    fd
    ripgrep

    # NixOS deployment tools
    nixos-anywhere
    deploy-rs
    nixos-rebuild
    
    # Encryption and secrets management
    age
    sops
    gnupg
    ssh-to-age
    
    # Network and system tools
    openssh
    netcat
    nmap
    tcpdump
    dig
    
    # Development and scripting tools
    python3
    nodejs
    bash
    shellcheck
    
    # Container tools (generic - not swarm specific)
    docker
    docker-compose
    
    # Monitoring tools
    prometheus
    grafana
    
    # DPS management tools (will be installed from deployTools/)
    (writeScriptBin "dps-deploy" ''
      #!/bin/bash
      # DPS Deployment CLI
      cd /opt/dps-tools
      exec ./cluster-deploy.sh "$@"
    '')
    
    (writeScriptBin "dps-node" ''
      #!/bin/bash
      # DPS Node Management CLI
      cd /opt/dps-tools
      exec ./node-manage.sh "$@"
    '')
    
    (writeScriptBin "dps-secrets" ''
      #!/bin/bash
      # DPS Secrets Management CLI
      cd /opt/dps-tools
      exec ./secrets-sync.sh "$@"
    '')
  ];

  # Git configuration for deployment operations
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
      pull.rebase = false;
      user.name = "DPS Deploy VM";
      user.email = "deploy@dps.local";
    };
  };

  # Enable flakes and modern Nix features
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "admin" ];
  };

  # Allow unfree packages (for some monitoring tools)
  nixpkgs.config.allowUnfree = true;

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Services for Deploy VM
  services = {
    # Enable Docker for container management
    docker = {
      enable = true;
      autoPrune.enable = true;
    };
    
    # Enable Prometheus for monitoring
    prometheus = {
      enable = true;
      port = 9090;
      listenAddress = "127.0.0.1";
    };
  };

  # Security hardening
  security = {
    # Disable root login
    sudo.wheelNeedsPassword = false;
    
    # Enable fail2ban
    fail2ban = {
      enable = true;
      maxretry = 3;
    };
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      22    # SSH
      9090  # Prometheus (local only)
    ];
  };

  # System state version - will be set by bootstrap
  system.stateVersion = lib.mkDefault "23.11";
}
