{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.open-codex;
in
{
  options.programs.open-codex = {
    enable = mkEnableOption "open-codex CLI coding agent";

    package = mkOption {
      type = types.package;
      default = pkgs.emptyDirectory;
      description = "The open-codex package to use.";
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Configuration for open-codex.";
      example = literalExpression ''
        {
          model = "o4-mini";
          provider = "openai";
          fullAutoErrorMode = "ask-user";
        }
      '';
    };

    environmentVariables = mkOption {
      type = with types; attrsOf str;
      default = { };
      description = "Environment variables to set for open-codex, like API keys.";
      example = literalExpression ''
        {
          OPENAI_API_KEY = "sk-...";
        }
      '';
    };

    approvalMode = mkOption {
      type = types.enum [
        "manual"
        "auto-edit"
        "full-auto"
      ];
      default = "manual";
      description = "Default approval mode for the open-codex CLI.";
    };
  };

  config = mkIf cfg.enable {
    home = {
      packages = [ cfg.package ];
      file = {
        ".codex/.keep".text = "";
        ".codex/config.json" = {
          text = builtins.toJSON cfg.settings;
        };
      };
      sessionVariables = cfg.environmentVariables;
    };
    programs = {
      bash.shellAliases = mkIf config.programs.bash.enable {
        open-codex = "open-codex --approval-mode ${cfg.approvalMode}";
      };
      zsh.shellAliases = mkIf config.programs.zsh.enable {
        open-codex = "open-codex --approval-mode ${cfg.approvalMode}";
      };
      fish.shellAliases = mkIf config.programs.fish.enable {
        open-codex = "open-codex --approval-mode ${cfg.approvalMode}";
      };
    };
  };
}
