<!-- codex.md: Documentation for the codex-cli Nix Home Manager module -->
# codex-cli Nix Home Manager Module

This Home Manager module manages the configuration file for the Codex CLI (codex) tool.

## Overview

- Module path: `programs.codex-cli`
- Generates: `$XDG_CONFIG_HOME/codex/config.yaml`
- Manages core options and merges any additional settings you provide.

> **Note:** This module does *not* install the Codex CLI binary itself. Ensure that `codex` is
> available in your `home.packages` or system `$PATH` by installing it separately.

## Options
All options are available under `programs.codex-cli`:

| Option              | Type                                    | Default      | Description                                                              |
|---------------------|-----------------------------------------|--------------|--------------------------------------------------------------------------|
| `enable`            | `bool`                                  | `false`      | Enable the module and write the config file.                             |
| `autoApprovalMode`  | one of `"suggest"`, `"auto-edit"`, `"full-auto"` | `suggest`    | How Codex CLI should handle suggested changes automatically.              |
| `fullAutoErrorMode` | one of `"ask-user"`, `"ignore-and-continue"`    | `ask-user`   | Behavior on errors when in `full-auto` mode.                             |
| `model`             | `string`                                | `o4-mini`    | The model identifier for Codex operations.                                |
| `memory`            | `bool`                                  | `false`      | Enable session memory (persist conversation history).                     |
| `apiKey`            | `string`                                | `""`        | Your API key for authenticating with the Codex service.                   |
| `settings`          | `attrset` (attributes set)              | `{}`         | Arbitrary settings to merge into the generated YAML config.               |

## Usage

In your NixOS or Home Manager flake, import and enable the module. For example:

```nix
{ inputs, ... }:

let
  # Alias this repo as "home-modules"
  home-modules = inputs.nix-home-modules;
  pkgs         = import inputs.nixpkgs { system = "x86_64-linux"; };
in
{
  outputs.homeConfigurations.myHost = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.home-manager.hmModules.programs.home-manager
      home-modules.homeManagerModules.codex-cli
    ];
    configuration = {
      programs.codex-cli.enable            = true;
      programs.codex-cli.apiKey            = "<YOUR_API_KEY>";
      programs.codex-cli.model             = "o4-mini";
      programs.codex-cli.memory            = true;
      programs.codex-cli.autoApprovalMode  = "suggest";
      # Merge any additional Codex config options:
      programs.codex-cli.settings = {
        logLevel = "debug";
      };
    };
    homeDirectory = "/home/username";
    username      = "username";
  };
}
```

After activating your Home Manager configuration, you will find your consolidated
Codex CLI config at:

```
$XDG_CONFIG_HOME/codex/config.yaml
```

## Generated config example
```yaml
autoApprovalMode: suggest
fullAutoErrorMode: ask-user
model: o4-mini
memory: true
apiKey: <YOUR_API_KEY>
logLevel: debug
```

## Example: Minimal configuration
```nix
programs.codex-cli = {
  enable = true;
  apiKey = "<YOUR_API_KEY>";
};
```

## See also
- [Codex CLI documentation](https://github.com/codex-team-ai/codex-cli)
- [Codex CLI configuration reference](https://github.com/codex-team-ai/codex-cli#configuration)

---

*This module only manages the config file; you must install the Codex CLI tool separately (e.g. via a pre-built binary or Nix package if available).* 

---

_Last updated: 2024-06_
