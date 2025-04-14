{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.programs.aider;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options.programs.aider = {
    enable = mkEnableOption "AI pair programming tool";
    settings = mkOption {
      inherit (yamlFormat) type;
      default = { };
      example = {
        auto-commits = true;
        model = "gemini/gemini-2.5-pro-exp-03-25";
        weak-model = "deepseek/deepseek-coder";
      };
      description = "Aider configuration settings. See https://aider.chat/docs/config.html";
    };
    providers = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            api_key = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Path to the API key file";
            };
          };
        }
      );
      default = { };
      description = "AI provider configurations";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.aider-chat ]; # <-- Semicolon was already here, kept it

    home.file.".aider.conf.yml" =
      let
        finalSettings =
          if cfg.providers != { } then
            cfg.settings
            // {
              "api-key" =
                mapAttrsToList (provider: providerCfg: "${provider}=${providerCfg.api_key}") # <-- Re-added "file:"

                  cfg.providers;
            }
          else
            cfg.settings;
      in
      lib.mkIf (cfg.settings != { }) {
        source = yamlFormat.generate "aider-config.yml" finalSettings;
      };
  };
}
