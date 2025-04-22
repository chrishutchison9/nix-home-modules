{
  config,
  lib,
  ...
}:
let
  cfg = config.apps.roocode;
in
{
  options.apps.roocode = {
    enable = lib.mkEnableOption "Enable Roo Code configuration";
    mcpSettingsPath = lib.mkOption {
      type = lib.types.path;
      default = "${config.home.homeDirectory}/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json";
      description = "Path to the mcp_settings.json file";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.setupRooCodeMcp = lib.mkAfter [ "writeBoundary" ] ''
      mkdir -p "$(dirname ${cfg.mcpSettingsPath})"
      rm -f "${cfg.mcpSettingsPath}"
      cat > "${cfg.mcpSettingsPath}" << EOF
      ${builtins.toJSON {
        mcpServers = {
          github = {
            command = "npx";
            args = [
              "-y"
              "@modelcontextprotocol/server-github"
            ];
            env = {
              GITHUB_PERSONAL_ACCESS_TOKEN = builtins.readFile config.sops.secrets.gh_token.path;
            };
            disabled = false;
            autoApprove = [ ];
          };
        };
      }}
      EOF
      chmod 400 "${cfg.mcpSettingsPath}"
    '';
  };
}