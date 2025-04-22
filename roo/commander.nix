# This is a Home Manager module for installing the build scripts
# and configuration assets for the Roo Commander codebase.
#
# When enabled, it will:
# 1. Install the Node.js build scripts (`build_mode_summary.js`, `build_roomodes.js`, `create_build.js`)
#    to the user's PATH.
# 2. Copy the standard configuration files and directories (`.ruru/`, `.roo/`, `.roomodes`, etc.)
#    to a designated location in the user's home directory (`~/.local/share/roocommander/config/v7.2/`).
# 3. Add a Home Manager activation message informing the user where the config files are located
#    and instructing them to copy these files to their VS Code workspace root.
#
# Example usage in your Home Manager configuration (home.nix):
# { inputs, outputs, lib, config, pkgs, ... }:
#
# {
#   imports = [
#     # Import your other modules...
#     # Assuming this file is named 'roo-commander.nix' in your config files
#     ./path/to/your/config/files/roo-commander.nix
#   ];
#
#   # Enable the Roo Commander scripts and configuration
#   programs.rooCommanderScripts.enable = true;
#
#   # (Optional) Configure other aspects if supported by the module
#   # programs.rooCommanderScripts.userPreferences = {
#   #   userName = "Your Name";
#   #   verbosityLevel = "verbose";
#   # };
# }
#

{ config, pkgs, lib, ... }:

let
  # Get the source code of the Roo Commander repository.
  # This example assumes the Nix file is located at the root of the codebase
  # during evaluation. For a globally usable Home Manager module, you would
  # typically replace this with `pkgs.fetchFromGitHub` or a similar fetcher
  # that points to a specific version (tag or commit) of the repository.
  #
  # Example using fetchFromGitHub:
  # rooCommanderSrc = pkgs.fetchFromGitHub {
  #   owner = "RooVetGit"; # Replace with actual owner if different
  #   repo = "Roo-Code";    # Replace with actual repo if different
  #   rev = "v7.0.6";        # Use a specific version tag or commit hash
  #   sha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX="; # Replace with the actual hash of that revision
  # };
  #
  # Using pkgs.path ./.; is suitable when the .nix module file is *within*
  # the source directory being managed by Home Manager.
  rooCommanderSrc = pkgs.path ./.; # Assuming the module file is in the codebase root

  # Get the version from the package.json file in the source
  pkgVersion = (lib.fromJSON (lib.readFile "${rooCommanderSrc}/package.json")).version or "unspecified";

  # Define the derivation for the build scripts
  # These are the executable .js files that the user will run.
  rooCommanderScriptsDerivation = pkgs.stdenv.mkDerivation {
    pname = "roo-commander-scripts";
    version = pkgVersion;
    src = rooCommanderSrc;

    # Filter the source to get only the script files
    filter = name: type: builtins.elem name ["build_mode_summary.js" "build_roomodes.js" "create_build.js"];

    # Copy scripts to $out/bin and make them executable
    installPhase = ''
      mkdir -p $out/bin
      cp $src/build_mode_summary.js $out/bin/build-mode-summary
      cp $src/build_roomodes.js $out/bin/build-roomodes
      cp $src/create_build.js $out/bin/create-roo-build

      # Add a shebang line and make the scripts executable.
      chmod +x $out/bin/*
      # Use perl -pi -e for in-place editing without requiring specific GNU tools or tmp files
      # Note: This assumes standard script content doesn't break sed/perl.
      # A safer alternative might be to create wrapper scripts in $out/bin
      # that explicitly call 'node path/to/script'.
      ${pkgs.perl}/bin/perl -pi -e 's|^|#!/usr/bin/env node\n| if $. == 1' $out/bin/*
    '';

    # Specify Node.js as a build input so the scripts can be executed
    buildInputs = [ pkgs.nodejs ];

    meta = {
      description = "Executable build scripts for the Roo Commander AI orchestration system.";
      homepage = "https://github.com/RooVetGit/Roo-Code"; # Assuming homepage
      license = lib.licenses.mit; # From LICENSE file content
      # platforms = lib.platforms.unix; # Assuming primarily Linux/macOS scripts
    };
  };

  # Define the derivation for the configuration assets tree
  # These are the files/directories that match the structure of the release zip archive.
  rooCommanderConfigAssetsDerivation = pkgs.stdenv.mkDerivation {
    pname = "roo-commander-config-assets";
    version = pkgVersion;
    src = rooCommanderSrc;

    # Define the files/directories to include relative to src
    # These items should be copied to the user's workspace root
    includedItems = [
      ".ruru/modes"
      ".ruru/processes"
      ".roo"
      ".ruru/templates"
      ".ruru/workflows"
      ".ruru/docs"
      ".roomodes"
      "LICENSE" # Include project LICENSE
      # README.md and CHANGELOG.md templates will be handled by copying specific template files
    ];

    # Define directories that should exist but may be empty in the source
    emptyDirs = [
      ".ruru/archive"
      ".ruru/context"
      ".ruru/decisions"
      ".ruru/ideas"
      ".ruru/logs"
      ".ruru/planning"
      ".ruru/reports"
      ".ruru/snippets"
      ".ruru/tasks"
    ];

    # Define paths to template files that should be included as root files in the output
    # These are the distribution README and CHANGELOG.
    readmeTemplate = "${rooCommanderSrc}/.ruru/templates/build/README.dist.md";
    changelogTemplate = "${rooCommanderSrc}/.ruru/templates/build/CHANGELOG.md";


    installPhase = ''
      # Create the main output directory for the config tree
      mkdir -p $out

      # Copy explicitly included files and directories from the source
      for item in $includedItems; do
        # Use cp -R to handle both files and directories
        # Check if item exists before attempting to copy to avoid errors
        if [ -e "$src/$item" ]; then
          echo "Copying included item: $item"
          cp -R "$src/$item" "$out/"
        else
          # Log a warning if an expected included item is missing
          echo "Warning: Included item not found in src, skipping: $item"
        fi
      done

      # Create explicitly defined empty directories in the output tree
      for dir in $emptyDirs; do
        echo "Creating empty directory: $dir"
        mkdir -p "$out/$dir"
      done

      # Copy specific template files to the root of the output tree
      echo "Copying distribution README and CHANGELOG templates..."
      # Ensure the template files actually exist before trying to copy
      if [ -e "$readmeTemplate" ]; then
          cp "$readmeTemplate" "$out/README.md"
      else
          echo "Error: Distribution README template not found at ${readmeTemplate}."
          exit 1 # Fail the build if critical files are missing
      fi

      if [ -e "$changelogTemplate" ]; then
          cp "$changelogTemplate" "$out/CHANGELOG.md"
      else
          echo "Error: CHANGELOG template not found at ${changelogTemplate}."
          exit 1 # Fail the build if critical files are missing
      }
    '';

    # No extra buildInputs are needed for just copying files
    # buildInputs = [];

    meta = {
      description = "Configuration files and directories (matching zip archive structure) for the Roo Commander AI orchestration system.";
      homepage = "https://github.com/RooVetGit/Roo-Code";
      license = lib.licenses.mit;
      # platforms = lib.platforms.unix;
    };
  };

in
{
  # Define the option to enable this module
  options.programs.rooCommanderScripts = {
    enable = lib.mkEnableOption "Make Roo Commander build scripts and configuration assets available.";

    # This module could be extended to manage user-specific configurations
    # like .roo/rules/00-user-preferences.md based on Nix options.
    # For example:
    # userPreferences = {
    #   enable = lib.mkEnableOption "Manage Roo Commander user preferences file.";
    #   # Define options for the TOML fields
    #   userName = lib.mkOption { type = lib.types.str; description = "User's name."; default = ""; };
    #   verbosityLevel = lib.mkOption { type = lib.types.enum [ "concise" "normal" "verbose" ]; description = "Preferred verbosity level."; default = "normal"; };
    #   preferredModes = lib.mkOption { type = with lib.types; listOf str; description = "List of preferred mode slugs."; default = []; };
    #   autoExecuteCommands = lib.mkOption { type = lib.types.bool; description = "Enable auto-execution of commands."; default = false; };
    #   preferredLanguage = lib.mkOption { type = lib.types.str; description = "Preferred language code (e.g., 'en')."; default = "en"; };
    # };
  };

  # Define the configuration applied when the module is enabled
  config = lib.mkIf cfg.enable {
    # Add the script derivation to the user's home.packages, making scripts executable in PATH
    home.packages = [ rooCommanderScriptsDerivation ];

    # Copy the configuration assets derivation's output to a standard location in the user's home.
    # This location is where the user would typically extract the zip archive.
    # The user is still responsible for copying these files from here to their VS Code workspace root.
    # We use a versioned path under ~/.local/share to avoid cluttering ~/.config and allow multiple versions.
    home.file.".local/share/roocommander/config/v7.2".source = rooCommanderConfigAssetsDerivation;

    # Add a Home Manager activation message to inform the user where the config files were placed.
    home.activation.scripts = [
      # Ensure this script runs only if the module is enabled
      lib.mkIf cfg.enable {
        __raw = ''
          # Inform the user about the location of Roo Commander configuration assets
          echo "--- Roo Commander Configuration ---"
          echo "Roo Commander v${pkgVersion} configuration assets have been installed to $HOME/.local/share/roocommander/config/v${pkgVersion}/"
          echo "To enable Roo Commander features in your VS Code workspace, please copy the *contents* of this directory (including hidden files like .ruru/ and .roo/) to your VS Code workspace root directory."
          echo "Example (assuming you are in your workspace root):"
          echo "cp -R $HOME/.local/share/roocommander/config/v${pkgVersion}/.ruru ./"
          echo "cp -R $HOME/.local/share/roocommander/config/v${pkgVersion}/.roo ./"
          echo "cp $HOME/.local/share/roocommander/config/v${pkgVersion}/.roomodes ./"
          echo "cp $HOME/.local/share/roocommander/config/v${pkgVersion}/README.md ./"
          echo "cp $HOME/.local/share/roocommander/config/v${pkgVersion}/CHANGELOG.md ./"
          echo "cp $HOME/.local/share/roocommander/config/v${pkgVersion}/LICENSE ./"
          echo "------------------------------------"
          echo "" # Add a blank line for readability
        '';
      }
    ];

    # Optional: Configure generation of user preferences file based on options
    # lib.mkIf (cfg.userPreferences.enable or false) { # Use (or false) to handle cases where userPreferences is not defined
    #   # Define the path for the user preferences file within the standard structure
    #   let userPreferencesPath = ".ruru/user_preferences.md"; # Example path within the structure
    #   let fullTargetDir = path.join config.home.homeDirectory ".local/share/roocommander/config/v${pkgVersion}";

    #   home.file."${fullTargetDir}/${userPreferencesPath}".text =
    #     let
    #        # Generate TOML content based on user preferences options
    #        # Note: Ensure consistency with the actual template structure if needed
    #        tomlContent = pkgs.lib.generators.toTOML {} {
    #           id = "user-preferences";
    #           title = "User Preferences";
    #           context_type = "configuration";
    #           scope = "User-specific settings and profile information";
    #           target_audience = ["all"];
    #           granularity = "detailed";
    #           status = "active";
    #           last_updated = lib.dateFormat "%Y-%m-%d" (builtins.currentTime); # Use deterministic date for builds if possible
    #           tags = ["user", "preferences", "configuration", "profile"];
    #           user_name = cfg.userPreferences.userName;
    #           skills = cfg.userPreferences.skills; # Assumes skills is an array option
    #           roo_usage_preferences = {
    #             preferred_modes = cfg.userPreferences.preferredModes; # Assumes preferredModes is an array option
    #             verbosity_level = cfg.userPreferences.verbosityLevel;
    #             auto_execute_commands = cfg.userPreferences.autoExecuteCommands;
    #             preferred_language = cfg.userPreferences.preferredLanguage;
    #           };
    #         };
    #     in
    #     ''
    #       +++
    #       ${tomlContent}
    #       +++
    #
    #       # User Preferences Data (Managed by Home Manager)
    #       # This file stores user-specific preferences and profile information.
    #       # This file is generated by Home Manager based on your configuration.
    #       # Do not edit this file directly in your workspace; manage it via your Home Manager configuration.
    #     '';
    # };
  };
}
