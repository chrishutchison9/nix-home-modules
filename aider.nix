{ config, lib, pkgs, ... }:

with lib;

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
        };
      };
      default = {};
      description = "Aider configuration settings";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];
    
    home.file.".aider.conf.yml".text = mkIf (cfg.settings != {}) ''
      auto-commits: ${if cfg.settings.autoCommits then "true" else "false"}
    '';
  };
}
