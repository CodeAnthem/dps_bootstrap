# bootstrap/lib

Feature-based layout — each folder owns one concern.

```
lib/
├── core/           Shared UI, runtime, import utilities
├── configurator/   Wizard, presets, validators (by domain)
├── classicConfig/  /etc/nixos configuration.nix builder (classicInstall only)
├── installer/      nixos-install pipeline
├── partition/      Disko + manual partitioning
├── setup/          Legacy helpers
└── load.sh         nds_configurator_init + nds_installation_init
```

Entry: `bootstrap/main.sh` → `core/import.sh` → `nds_bootstrap_load_libs`.
