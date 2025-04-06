{ config, lib, pkgs, ... }: with lib;

let
  cfg = config.programs.aider;
in
{
  options.programs.aider = {
    enable = mkEnableOption "AI pair programming tool";

    package = mkOption {
      type = types.package;
      default = pkgs.aider-chat;
      description = "The package to use for aider";
    };

    settings = mkOption {
      type = types.submodule {
        options = {
          autoCommits = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to automatically commit changes";
          };
          defaultModel = mkOption {
            type = types.str;
            default = "deepseek/deepseek-coder";
            description = "Default model to use with aider";
          };
        };
      };
      default = { };
      description = "Aider configuration settings";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".aider.conf.yml".text = mkIf (cfg.settings != { }) ''
      cache-prompts: true
      stream: false
      dark-mode: true
      attribute-author: false
      attribute-committer: false
      auto-commits: ${if cfg.settings.autoCommits then "true" else "false"}
      model: ${cfg.settings.defaultModel}
      edit-format: udiff
    '';
  };
}
