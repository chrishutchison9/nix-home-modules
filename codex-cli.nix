{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.programs.codex-cli;
  yamlFormat = pkgs.formats.yaml { };
in {
  options.programs.codex-cli = {
    enable = mkEnableOption "Manage codex CLI settings";

    autoApprovalMode = mkOption {
      type = types.enum [ "suggest" "auto-edit" "full-auto" ];
      default = "suggest";
      description = ''
        Mode for automatically approving suggestions.
        One of: "suggest", "auto-edit", "full-auto".
      '';
    };

    fullAutoErrorMode = mkOption {
      type = types.enum [ "ask-user" "ignore-and-continue" ];
      default = "ask-user";
      description = ''
        Behavior for errors in full-auto mode.
        One of: "ask-user", "ignore-and-continue".
      '';
    };
    model = mkOption {
      type = types.str;
      default = "o4-mini";
      description = ''
        Default model name for Codex CLI operations (e.g. "o4-mini").
      '';
    };
    memory = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable or disable use of memory in Codex CLI sessions.
      '';
    };
    apiKey = mkOption {
      type = types.str;
      default = "";
      description = ''
        API key for Codex CLI authentication.
      '';
    };

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = ''
        Additional configuration for codex CLI settings.
        These keys will be merged into the YAML at $XDG_CONFIG_HOME/codex/config.yaml.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.file."${config.xdg.configHome}/codex/config.yaml" = {
      source = yamlFormat.generate "codex-cli-config.yaml"
        (let base = {
            autoApprovalMode    = cfg.autoApprovalMode;
            fullAutoErrorMode   = cfg.fullAutoErrorMode;
            model               = cfg.model;
          };
         in cfg.settings // base
             // (if cfg.memory then { memory = true; } else {})
             // (if cfg.apiKey != "" then { apiKey = cfg.apiKey; } else {})
        );
    };
  };
}