# bootstrap/lib

Runtime backbone and install pipeline. Feature code lives in `core/`, `settingsManager/`, `tools/`.

```
lib/
├── core/       import.sh, runtime, platform
├── ui/         terminal, output, prompts, stepAnimation (primitives only)
├── install/    nixos-install steps (partition, encryption, bundle, …)
└── load.sh     settings init + installation stack load
```

See [ARCHITECTURE.md](../ARCHITECTURE.md) for the full map.

Load order: `core/bootstrap.sh` loads validators → settingsManager → ui → core/menus → actions → `lib/load.sh`.
